FactoryGirl.define do
  factory :response do
    ignore do
      _answers []
    end
    
    user
    form
    mission { get_mission }
    
    # build answer objects from _answers array
    answers do
      _answers.each_with_index.map do |a, idx|
        # build answer from string value
        qing = form.questionings[idx]
        ans = Answer.new(:questioning => qing)
        
        unless a.nil?
          case qing.qtype_name

          when 'select_one'
            option = qing.options.index_by(&:name)[a] or raise "could not find option with name '#{a}'"
            ans.option_id = option.id

          when 'select_multiple'
            # in this case, a should be either nil or an array of arrays of choice names
            options_by_name = qing.options.index_by(&:name)
            ans.choices = a.map do |c|
              option = options_by_name[c] or raise "could not find option with name '#{c}'"
              Choice.new(:option_id => option.id)
            end

          when 'date'
            ans.date_value = Date.parse(a)

          when 'time'
            ans.time_value = Time.zone.parse(a)

          else
            ans.value = a
          end
        end
        ans
      end
    end
  end
end