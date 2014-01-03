class Optioning < ActiveRecord::Base
  include MissionBased, FormVersionable, Standardizable, Replicable

  belongs_to(:option, :inverse_of => :optionings)
  belongs_to(:option_set, :inverse_of => :optionings)
  belongs_to(:option_level, :inverse_of => :optionings)

  before_create(:set_mission)
  before_destroy(:no_answers_or_choices)

  validate(:must_have_parent_if_not_top_option_level)

  accepts_nested_attributes_for(:option)

  # option level rank
  delegate :rank, :to => :option_level, :allow_nil => true, :prefix => true

  # replication options
  replicable :child_assocs => :option, :parent_assoc => :option_set

  # temp var used in the option_set form
  attr_writer :included

  def included
    # default to true
    defined?(@included) ? @included : true
  end

  # looks for answers and choices related to this option setting
  def has_answers_or_choices?
    !option_set.questions.detect{|q| q.questionings.detect{|qing| qing.answers.detect{|a| a.option_id == option_id || a.choices.detect{|c| c.option_id == option_id}}}}.nil?
  end

  def no_answers_or_choices
    raise DeletionError.new(:cant_delete_if_has_response) if has_answers_or_choices?
  end

  def removable?
    !has_answers_or_choices?
  end

  def as_json(options = {})
    if options[:for_option_set_form]
      super(:only => :id, :methods => :removable?).merge(:option => option.as_json(:for_option_set_form => true))
    else
      super(options)
    end
  end

  private

    # copy mission from option_set
    def set_mission
      self.mission = option_set.try(:mission)
    end

    def must_have_parent_if_not_top_option_level
      errors.add(:parent_id, "can't be blank if not top option level") if option_level_rank.present? && option_level_rank > 1
    end
end
