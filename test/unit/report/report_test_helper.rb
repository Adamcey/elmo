module ReportTestHelper

  def prep_objects
    Role.generate
    
    # clear out tables
    [Question, Questioning, Answer, Form, User, Mission].each{|k| k.delete_all}
    
    # create hashes to store generated objs
    @questions, @forms, @option_sets, @users, @missions = {}, {}, {}, {}, {}
  end
  
  def create_report(options)
    Report::Report.create!({:name => "TheReport", :mission => mission, :question_labels => :codes}.merge(options))
  end

  def create_opt_set(options)
    os = OptionSet.new(:name => options.join, :ordering => "value_asc", :mission => mission)
    options.each_with_index{|o,i| os.option_settings.build(:option => Option.new(:value => i+1, :name_eng => o))}
    os.save!
    @option_sets[options.join("_").downcase.to_sym] = os
  end

  def create_form(params)
    f = Form.new(params.merge(:mission => mission))
    f.save(:validate => false)
    @forms[params[:name].to_sym] = f
  end
  
  def mission
    @missions[:test] ||= Mission.create!(:name => "test")
  end
  
  def user
    return @users[:test] if @users[:test]
    @users[:test] = User.new_with_login_and_password(:login => "test", :name => "Test", :reset_password_method => "print")
    @users[:test].assignments.build(:mission => mission, :active => true, :role => Role.highest)
    @users[:test].save!
    @users[:test]
  end

  def create_question(params)
    QuestionType.generate
    
    # create default form if necessary
    params[:forms] ||= [create_form(:name => "f")]  
  
    q = Question.new(:name_eng => params[:code], :code => params[:code], :mission => mission,
      :question_type_id => QuestionType.find_by_name(params[:type]).id)
  
    # set the option set if type is select_one or select_multiple
    q.option_set = params[:option_set] || @option_sets.first[1] if %w(select_one select_multiple).include?(params[:type])
  
    # create questionings for each form
    params[:forms].each{|f| q.questionings.build(:form => f)}
  
    # save and store in hash
    q.save!
    @questions[params[:code].to_sym] = q
  end

  def create_response(params)
    ans = params.delete(:answers) || {}
    params[:form] ||= @forms[:f] || create_form(:name => "f")
    r = Response.new({:reviewed => true, :user => user, :mission => mission}.merge(params))
    ans.each_pair do |code,value|
      qing = @qs[code].questionings.first
      case qing.question.type.name
      when "select_one"
        # create answer with option_id
        r.answers.build(:questioning_id => qing.id, :option => qing.question.options.find{|o| o.name_eng == value})
      when "select_multiple"
        # create answer with several choices
        a = r.answers.build(:questioning_id => qing.id)
        value.each{|opt| a.choices.build(:option => qing.question.options.find{|o| o.name_eng == opt})}
      when "datetime", "date", "time"
        a = r.answers.build(:questioning_id => qing.id, :"#{qing.question.type.name}_value" => value)
      else
        r.answers.build(:questioning_id => qing.id, :value => value)
      end
    end
    r.save!
    r
  end

  def set_eastern_timezone
    Time.zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  def assert_report(report, *expected)
    report.run
    if expected.first.nil?
      assert_nil(report.data) 
    else
      raise "Report errors: " + report.errors.full_messages.join(", ") unless report.errors.empty?
      raise "Missing headers" if report.headers.nil? || report.headers[:col].nil? || report.headers[:row].nil?
      raise "Bad data array" if report.data.nil? || report.data.empty?
      actual = [report.headers[:col].collect{|h| h[:name]}]
      # generate the expected value
      report.data.each_with_index do |row, i| 
        rh = report.headers[:row][i] ? Array.wrap(report.headers[:row][i][:name]) : []
        actual += [rh + row.collect{|x| x.to_s}]
      end
      assert_equal(expected, actual)
    end
  end
end