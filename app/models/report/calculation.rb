class Report::Calculation < ActiveRecord::Base
  attr_accessible :type, :report_report_id, :attrib1_name, :question1_id, :arg1, :attrib1, :question1
  attr_writer :table_prefix
  
  belongs_to :report, :class_name => "Report::Report", :foreign_key => "report_report_id"
  belongs_to :question1, :class_name => "Question"
  
  # HACK TO GET STI TO WORK WITH ACCEPTS_NESTED_ATTRIBUTES_FOR
  class << self
    def new_with_cast(*a, &b)
      if (h = a.first).is_a? Hash and (type = h[:type] || h['type']) and (klass = type.constantize) != self
        raise "wtF hax!!"  unless klass < self  # klass should be a descendant of us
        return klass.new(*a, &b)
      end

      new_without_cast(*a, &b)
    end
    alias_method_chain :new, :cast
  end

  def self.types
    [{
      :name => "Report::IdentityCalculation",
      :title => "None"
    },{
      :name => "Report::ZeroNonzeroCalculation",
      :title => "Whether an answer is 0 or greater than 0"
    }]
  end
  
  def as_json(options = {})
    h = super(options)
    h[:type] = type
    return h
  end
  
  def arg1
    (a1 = answer1) ? a1 : attrib1
  end
  
  def attrib1
    key = self.attrib1_name
    return key ? Report::AttribField.get(key) : nil
  end

  def answer1
    @answer1 ||= question1 ? Report::AnswerField.new(question1) : nil
  end
  
  def arg1=(arg)
    if arg.is_a?(Report::AnswerField)
      self.answer1 = arg
    else
      self.attrib1 = arg
    end
  end
  
  def answer1=(answer)
    self.question1_id = answer.question.id
  end 

  def attrib1=(attrib)
    self.attrib1_name = attrib.name
  end
  
  def header_title
    attrib1 ? attrib1.name : question1.code
  end
  
  def table_prefix
    @table_prefix.blank? ? "" : (@table_prefix + "_")
  end
end
