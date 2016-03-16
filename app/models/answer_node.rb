# Models a group of answers in a single repeat-instance of a single FormItem
# (either group or individual question) on a single response.
# See AnswerArranger for more documentation.
class AnswerNode
  attr_accessor :item, :instances, :placeholder_instance, :set

  delegate :repeatable?, to: :item

  def initialize(params)
    self.item = params[:item]
    self.instances = []
    self.set = params[:set]
  end

  def normalize
    return if instances.empty?
    instances.reject(&:marked_for_destruction?).each_with_index do |instance, i|
      instance.update_inst_num(i + 1)
    end
    instances.each(&:normalize)
  end

  def empty?
    set ? set.blank? : instances.all?(&:blank?)
  end

  def mark_for_destruction
    if set
      set.answers.each(&:mark_for_destruction)
    else
      instances.each(&:mark_for_destruction)
    end
  end

  def marked_for_destruction?
    set ? set.answers.all?(&:marked_for_destruction?) : instances.all?(&:marked_for_destruction?)
  end

  # If this node is a individual question, updates the inst_num of all answers.
  def update_inst_num(num)
    set.answers.each { |a| a.inst_num = num } if set
  end
end
