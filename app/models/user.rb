class User < ActiveRecord::Base
  belongs_to(:role)
  belongs_to(:language)
  belongs_to(:location)
  before_validation(:clean_fields)
  before_destroy(:check_assoc)
  has_many(:responses)
  
  acts_as_authentic
  validates(:first_name, :presence => true)
  validates(:last_name, :presence => true)
  validates(:role_id, :presence => true)
  validates(:language_id, :presence => true)
  validate(:phone_length_or_empty)

  def self.select_options
    find(:all, :order => "first_name, last_name").collect{|u| [u.full_name, u.id]}
  end
  def self.sorted(params)
    params.merge!(:order => "users.last_name, users.first_name")
    paginate(:all, params)
  end
  def self.default(params = {})
    User.new({:is_mobile_phone => true, :active => true, :language_id => Language.english.id}.merge(params))
  end
  def self.new_with_login_and_password(params)
    u = new(params)
    u.password = u.password_confirmation = random_password
    u.generate_login!
    u
  end
  def self.random_password(size = 8)
    charset = %w{2 3 4 6 7 9 a c d e f g h j k m n p q r t v w x y z}
    (0...size).map{charset.to_a[rand(charset.size)]}.join
  end
  def self.find_by_credentials(login, password)
    user = find_by_login(login)
    (user && user.valid_password?(password)) ? user : nil
  end
  
  def self.default_eager
    [:language, :role]
  end
  
  # gets the list of fields to be searched for this class
  # includes whether they should be included in a default, unqualified search
  # and whether they are searchable by a regular expression
  def self.search_fields
    {:firstname => {:colname => "users.firstname", :default => true, :regexp => true},
     :lastname => {:colname => "users.lastname", :default => true, :regexp => true},
     :login => {:colname => "users.login", :default => true, :regexp => true},
     :language => {:colname => "languages.name", :default => false, :regexp => false},
     :role => {:colname => "roles.name", :default => false, :regexp => false},
     :email => {:colname => "users.email", :default => false, :regexp => true},
     :phone => {:colname => "users.phone", :default => false, :regexp => true}}
  end
  
  # returns the lhs, operator, and rhs of a query fragment with the given field and term
  def self.query_fragment(field, term)
    [search_fields[field][:colname], "like", "%#{term}%"]
  end
  
  def self.search_examples
    ["pinchy lombard", 'role:observer', "language:english", "phone:+44"]
  end
  
  def generate_login!
    base = "#{first_name[0,1]}#{last_name}".downcase.normalize
    try = 1
    until self.class.find_by_login(self.login = base + (try > 1 ? try.to_s : "")).nil?
      try += 1
    end
  end
  def phone_number
    phone.blank? ? "" : phone + (is_mobile_phone? ? " [m]" : "")
  end
  def deliver_intro!
    reset_perishable_token!
    Notifier.intro(self).deliver
  end
  def deliver_password_reset_instructions!
    reset_perishable_token!
    Notifier.password_reset_instructions(self).deliver  
  end
  def full_name
    "#{first_name} #{last_name}"
  end
  
  def is_observer?; role ? role.is_observer? : false; end
  def is_program_staff?; role ? role.is_program_staff? : false; end
  
  private
    def clean_fields
      self.phone = "+" + phone.gsub(/[^0-9]/, "") unless phone.blank?
    end
    
    def phone_length_or_empty
      errors.add(:phone, "must be at least 9 digits.") unless phone.blank? || phone.size >= 10
    end
    
    def check_assoc
      # Can't delete users with related responses.
      unless responses.empty?
        raise("You can't delete #{full_name} because he/she has associated responses." +
          (active? ? " Try setting him/her to inactive." : ""))
      end
    end
end
