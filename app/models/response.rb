require 'xml'
require 'place_lookupable'

class Response < ActiveRecord::Base
  include PlaceLookupable
  
  belongs_to(:form)
  belongs_to(:place)
  has_many(:answers, :include => :questioning, :order => "questionings.rank", 
    :autosave => true, :validate => false, :dependent => :destroy)
  belongs_to(:user)
  
  attr_accessor(:modifier)
  
  # we turn off validate above and do it here so we can control the message and have only one message
  # regardless of how many answer errors there are
  validates(:user, :presence => true)
  validates(:observed_at, :presence => true)
  validate(:no_missing_answers)

  # only need to validate answers in web mode
  validates_associated(:answers, :message => "are invalid (see below)", :if => Proc.new{|r| r.modifier == "web"})
  
  before_save(:set_place)
  
  def self.per_page; 20; end
  
  def self.flattened(params = {})
    params[:conditions] ||= "1"
    params[:conditions].gsub!(/responses\./, '')
    find_by_sql("select * from _answers where (#{params[:conditions]})")
  end
  
  def self.sorted(params = {})
    params.merge!(:order => "responses.created_at desc")
    send(params.keys.include?(:page) ? "paginate" : "find", :all, params)
  end
  
  def self.default_eager
    [{:form => :type}, :user, :place]
  end
  
  def self.find_eager(id)
    find(id, :include => [
      :form,
      {:answers => 
        [{:choices => {:option => :translations}},
         {:option => :translations}, 
         {:questioning => {:question => 
           [:type, :translations, {:option_set => {:options => :translations}}]
         }}
        ]
      }
    ])
  end
  
  # gets the list of fields to be searched for this class
  # includes whether they should be included in a default, unqualified search
  # and whether they are searchable by a regular expression
  def self.search_fields
    {:formname => {:colname => "forms.name", :default => false, :regexp => true},
     :formtype => {:colname => "form_types.name", :default => false, :regexp => false},
     :reviewed => {:colname => "responses.reviewed", :default => false, :regexp => false},
     :place => {:colname => "places.full_name", :default => false, :regexp => true},
     :submitter => {:colname => "concat(users.first_name, ' ', users.last_name)", :default => false, :regexp => true},
     :answer => {:colname => "answers.value", :default => true, :regexp => true, :eager => [:answers]}}
  end
  
  # gets the lhs, operator, and rhs of a query fragment with the given field and term
  def self.query_fragment(field, term)
    case field
    when :formname, :formtype
      [search_fields[field][:colname], "=", "#{term}"]
    when :reviewed
      [search_fields[field][:colname], "=", {'yes' => '1', 'no' => '0'}[term.downcase] || '']
    else
      [search_fields[field][:colname], "like", "%#{term}%"]
    end
  end
  
  def self.search_examples
    ['submitter:"john smith"', 'formname:polling', 'formtype:sto', 'place:beirut']
  end

  def self.create_from_xml(xml, user)
    # parse xml
    doc = XML::Parser.string(xml).parse

    # get form id
    form_id = doc.root["id"] or raise ArgumentError.new("No form id.")
    form_id = form_id.to_i
    
    # create response object
    resp = new(:form_id => form_id, :user_id => user ? user.id : nil, :source => "odk", :modifier => "odk")
    qings = resp.form ? resp.form.visible_questionings : (raise ArgumentError.new("Invalid form id."))
    
    # loop over each child tag and create hash of question_code => value
    values = {}; doc.root.children.each{|c| values[c.name] = c.first? ? c.first.content : nil}
    
    # set the observe time if it's available
    if time = values.delete('startstamp')
      resp.observed_at = Time.zone.parse(time)
    end
    
    # loop over all the questions in the form and create answers
    place_bits = {}
    start_time = nil
    qings.each do |qing|
      # get value from hash
      str = values[qing.question.code]
      # add answer
      resp.answers << Answer.new_from_str(:str => str, :questioning => qing)
    end

    # save the works
    resp.save!
  end
  
  def visible_questionings
    # get visible questionings from form
    form.visible_questionings
  end
  
  def all_answers
    # make sure there is an associated answer object for each questioning in the form
    visible_questionings.collect{|qing| answer_for(qing) || answers.new(:questioning_id => qing.id)}
  end
  
  def all_answers=(params)
    # do a match on current and newer ids with the ID as the comparator
    answers.match(params.values, Proc.new{|a| a[:questioning_id].to_i}) do |orig, subd|
      # if both exist, update the original
      if orig && subd
        orig.attributes = subd
      # if submitted is nil, destroy the original
      elsif subd.nil?
        answers.delete(orig)
      # if original is nil, add the new one to this response's array
      elsif orig.nil?
        answers << Answer.new(subd)
      end
    end
  end

  def answer_for(questioning)
    # get the matching answer(s)
    answer_hash[questioning]
  end
  
  def answer_hash(options = {})
    @answer_hash = nil if options[:rebuild]
    @answer_hash ||= Hash[*answers.collect{|a| [a.questioning, a]}.flatten]
  end
  
  def observed_at_str; observed_at ? observed_at.strftime("%F %l:%M%p %z").gsub("  ", " ") : nil; end
  def observed_at_str=(t); self.observed_at = Time.zone.parse(t); end
  
  def form_name; form ? form.name : nil; end
  def submitter; user ? user.full_name : nil; end
  
  def place_field_name; "place"; end
  
  private
    def no_missing_answers
      answer_hash(:rebuild => true)
      visible_questionings.each do |qing|
        errors.add(:base, "Not all questions have answers") and return false if answer_for(qing).nil?
      end
    end
    
    def set_place
      # grab place from place bits unless the place has been set using the lookup tool
      unless place_id_changed?
        bits = {:changed => false}
        # loop over answers and find gps coords and/or place name, noting if either has changed      
        answers.each do |a|
          if bits[:coords].nil? && a.questioning.question.is_location?
            # if the gps location was set, split the string into lat/lng
            bits[:coords] = a.value? ? a.value.split(" ")[0..1] : false
            # note if the value was changed
            bits[:changed] = true if a.value_changed?
          elsif bits[:place_name].nil? && a.questioning.question.is_address?
            # save the place name
            bits[:place_name] = (a.value ? a.value[0..254] : "") || false
            # note if the value was changed
            bits[:changed] = true if a.value_changed?
          end
        end
        
        # find and set the place if either of the bits changed
        self.place = Place.find_or_create_with_bits(bits) if bits[:changed]
      end
      
      # ensure the place is non-temporary
      place.update_attributes(:temporary => false) if self.place
    end
end
