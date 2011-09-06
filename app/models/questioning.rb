class Questioning < ActiveRecord::Base
  belongs_to(:form)
  belongs_to(:question, :autosave => true)
  has_many(:answers, :dependent => :destroy)
  has_one(:condition, :autosave => true, :dependent => :destroy, :validate => false)
  has_many(:referring_conditions, :class_name => "Condition", :foreign_key => "ref_qing_id")
  
  before_create(:set_rank)
  before_destroy(:check_assoc)

  validates_associated(:condition, :message => "is invalid (see below)")
  
  alias :old_condition= :condition=
  
  def self.new_with_question(params = {})
    qing = new(params.merge(:question => Question.new))
  end

  def answer_required?
    required? && question.type.name != "select_multiple"
  end
  
  def published?
    form.published?
  end
  
  # returns any forms other than this one on which this questionings question appears
  def other_forms
    question.forms.reject{|f| f == form}
  end
  
  def method_missing(*args)
    # pass appropriate methods on to question
    if is_question_method?(args[0].to_s)
      question.send(*args)
    else
      super
    end
  end
 
  def respond_to?(symbol, *)
    is_question_method?(symbol.to_s) || super
  end
 
  def respond_to_missing?(symbol, include_private)
    is_question_method?(symbol.to_s) || super
  end
  
  def is_question_method?(symbol)
    symbol.match(/^((name|hint)_([a-z]{3})(=?)|code=?|option_set_id=?|question_type_id=?)(_before_type_cast)?$/)
  end
  
  def update_rank(new_rank)
    self.rank = new_rank
    save
  end
  
  def clone(new_form)
    cloned = self.class.new(:form_id => new_form.id, :question_id => question_id, :rank => rank, 
      :required => required, :hidden => hidden)
      
    # clone the condition if necessary
    cloned.build_condition(condition.attributes) if condition
    
    # return the clone
    cloned
  end
  
  def has_condition?; !condition.nil?; end
  
  def condition=(c)
    return old_condition=(c) unless c.is_a?(Hash)
    # if all attribs are blank, destroy the condition if it exists
    if c.reject{|k,v| v.blank?}.empty?
      condition.destroy if condition
    # otherwise, set the attribs or build a new condition if none exists
    else
      condition ? condition.attributes = c : build_condition(c)
    end
  end
  
  def get_or_init_condition
    has_condition? ? condition : build_condition
  end
  
  def previous_qings
    form.questionings.reject{|q| q == self || q.rank > rank}
  end
  
  def verify_condition_ordering
    condition.verify_ordering if condition
  end
  
  private
    def set_rank
      self.rank = form.max_rank + 1 if rank.nil?
      return true
    end
    
    def check_assoc
      unless referring_conditions.empty?
        raise("You can't remove question '#{question.code}' because one or more conditions refer to it.")
      end
      unless answers.empty?
        raise("You can't remove question '#{question.code}' because it has one or more answers for this form.")
      end
    end
end
