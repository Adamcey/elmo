class Question < ActiveRecord::Base
  include MissionBased, FormVersionable, Translatable
  
  belongs_to(:option_set, :include => :options, :inverse_of => :questions)
  has_many(:questionings, :dependent => :destroy, :autosave => true, :inverse_of => :question)
  has_many(:answers, :through => :questionings)
  has_many(:referring_conditions, :through => :questionings)
  has_many(:forms, :through => :questionings)

  validates(:name, :presence => true)
  validates(:code, :presence => true)
  validates(:code, :format => {:with => /^[a-z][a-z0-9]{1,19}$/i}, :if => Proc.new{|q| !q.code.blank?})
  validates(:qtype_name, :presence => true)
  validates(:option_set_id, :presence => true, :if => Proc.new{|q| q.qtype && q.has_options?})
  validate(:integrity)
  validate(:code_unique_per_mission)

  before_destroy(:check_assoc)
  before_save(:notify_form_versioning_policy_of_update)
  
  default_scope(order("code"))
  scope(:select_types, where(:qtype_name => %w(select_one select_multiple)))
  
  translates :name, :hint
  
  delegate :smsable?, :has_options?, :to => :qtype
  
  # returns questions that do NOT already appear in the given form
  def self.not_in_form(form)
    scoped.where("(questions.id not in (select question_id from questionings where form_id='#{form.id}'))")
  end
  
  # returns the question type object associated with this question
  def qtype
    QuestionType[qtype_name]
  end
  
  def options
    option_set ? option_set.sorted_options : nil
  end
  
  def select_options
    (opt = options) ? opt.collect{|o| [o.name, o.id]} : []
  end

  # determines if the question appears on any published forms
  def published?
    !forms.detect{|f| f.published?}.nil?
  end
  
  # an odk-friendly unique code
  def odk_code
    "q#{id}"
  end
  
  # shortcut method for tests
  def qing_ids
    questionings.collect{|qing| qing.id}
  end
  
  def min_max_error_msg
    return nil unless minimum || maximum
    clauses = []
    clauses << I18n.t("questions.maxmin.gt") + " " + (minstrictly ? "" : I18n.t("questions.maxmin.or_eq") + " " ) + minimum.to_s if minimum
    clauses << I18n.t("questions.maxmin.lt") + " " + (maxstrictly ? "" : I18n.t("questions.maxmin.or_eq") + " " ) + maximum.to_s if maximum
    I18n.t("layout.must_be") + " " + clauses.join(" " + I18n.t("common.and") + " ")
  end
  
  def as_json(options = {})
    {:id => id, :code => code, :qtype_name => qtype_name, :form_ids => forms.collect{|f| f.id}.sort}
  end
  
  private

    def integrity
      # error if type or option set have changed and there are answers or conditions
      if (qtype_name_changed? || option_set_id_changed?) 
        if !answers.empty?
          errors.add(:base, :cant_change_if_responses)
        elsif !referring_conditions.empty?
          errors.add(:base, :cant_change_if_conditions)
        end
      end
      
      # error if anything (except name/hint) has changed and the question is published
      errors.add(:base, :cant_change_if_published) if published? && (changed? && !changed.reject{|f| f =~ /^_?(name|hint)/}.empty?)
    end

    def check_assoc
      raise DeletionError.new(:cant_delete_if_in_form) unless questionings.empty?
    end

    def code_unique_per_mission
      errors.add(:code, :must_be_unique) unless unique_in_mission?(:code)
    end
end
