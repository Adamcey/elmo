# when run, this report generates a fairly complex data structure, as follows:
# StandardFormReport = {
#   :summary_collection => {
#     :subsets => [
#       {
#         :groups => [
#           {
#             :clusters => [
#               {:summaries => [summary, summary, ...]},
#               {:summaries => [summary, summary, ...]}
#             ]
#           },
#           {
#             :clusters => [
#               {:summaries => [summary, summary, ...]},
#               {:summaries => [summary, summary, ...]}
#             ]
#           }
#         ]
#       }
#     ]
#   }
# }
#

class Report::StandardFormReport < Report::Report
  belongs_to(:form)
  belongs_to(:disagg_qing, :class_name => 'Questioning')

  attr_reader :summary_collection

  # question types that we leave off this report (stored as a hash for better performance)
  EXCLUDED_TYPES = {'location' => true}

  # options for the question_order attrib
  QUESTION_ORDER_OPTIONS = %w(number type)

  def as_json(options = {})
    # add the required methods to the methods option
    h = super(options)
    h[:response_count] = response_count
    h[:mission] = form.mission.as_json(:only => [:id, :name])
    h[:form] = form.as_json(:only => [:id, :name])
    h[:subsets] = subsets
    h[:observers_without_responses] = observers_without_responses.as_json(:only => [:id, :name])
    h[:disagg_question_id] = disagg_question_id
    h[:disagg_qing] = disagg_qing.as_json(:only => :id, :include => {:question => {:only => :code}})
    h[:no_data] = no_data?
    h
  end

  def run
    # eager load form
    f = Form.includes({:questionings => [
      # eager load qing conditions
      {:condition => [:ref_qing, :option]},

      # eager load referring conditions and their questionings
      {:referring_conditions => :questioning},

      # eager load questions and their option sets
      {:question => {:option_set => :options}}
    ]}).find(form_id)

    # generate summary collection (sets of disaggregated summaries)
    @summary_collection = Report::SummaryCollectionBuilder.new(questionings_to_include(f), disagg_qing, :question_order => question_order).build
  end

  # returns the number of responses matching the report query
  def response_count
    @response_count ||= form.responses.count
  end

  # returns all non-admin users in the form's mission with the given (active) role that have not submitted any responses to the form
  # options[:role] - (symbol) the role to check for
  def users_without_responses(options)
    # eager load responses with users
    all_observers = form.mission.assignments.includes(:user).find_all{|a| a.role.to_sym == options[:role] && a.active? && !a.user.admin?}.map(&:user)
    submitters = form.responses.includes(:user).map(&:user).uniq
    @users_without_responses = all_observers - submitters
  end

  def observers_without_responses
    users_without_responses(:role => :observer)
  end

  # returns the list of questionings to include in this report
  # takes an optional form argument to allow eager loaded form
  def questionings_to_include(form = nil)
    @questionings_to_include ||= (form || self.form).questionings.reject do |qing|
      qing.hidden? || 
      Report::StandardFormReport::EXCLUDED_TYPES[qing.qtype.name] || 
      text_responses == 'short_only' && qing.qtype.name == 'long_text' ||
      text_responses == 'none' && qing.qtype.textual?
    end
  end

  def empty?
    summary_collection.nil? || summary_collection.no_data?
  end

  # no_data is a more accurate name
  alias_method :no_data?, :empty?

  def exportable?
    false
  end

  def disagg_question_id
    disagg_qing.try(:question_id)
  end

  def subsets
    summary_collection.try(:subsets)
  end

  # settor method allowing the disaggregation *question* and not *questioning* to be set
  def disagg_question_id=(question_id)
    self.disagg_qing = form.questionings.detect{|qing| qing.question_id == question_id.to_i}
  end
end
