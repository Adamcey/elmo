class Assignment < ActiveRecord::Base
  belongs_to(:mission)
  belongs_to(:role)
  belongs_to(:user)

  validates(:mission, :presence => true)
  validates(:role, :presence => true)
  
  # checks if there are any duplicates in the given set of assignments
  def self.duplicates?(assignments)
    # uniq! returns nil if there are no duplicates
    !assignments.collect{|a| a.mission}.compact.uniq!.nil?
  end
end
