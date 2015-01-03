def create_question(qtype_name, mission, option_names, multi_option_set, rank, parent=nil, form)
  qtype = QuestionType[qtype_name == 'multi_level_select_one' ? 'select_one' : qtype_name]
  question_attribs = {
    qtype_name: qtype.name,
    mission: mission,
    use_multilevel_option_set: multi_option_set || qtype_name == 'multi_level_select_one'
  }

  # assign the options to the question if appropriate
  if qtype.has_options? && !option_names.nil?
    question_attribs[:option_names] = option_names
  end

  qing = FactoryGirl.create(:questioning,
    :mission => mission,
    :rank => rank,
    :parent => parent,
    :form => form,
    :question => FactoryGirl.build(:question, question_attribs))
    
  # Keep legacy association intact.
  form.questionings << qing
  qing
end

# Only works with create
FactoryGirl.define do
  factory :form do
    ignore do
      question_types []
      use_multilevel_option_set false

      # optionally specifies the options for the option set of the first select type question on the form
      option_names nil
    end
    
    after(:create) do |form, evaluator|
      root = QingGroup.create!(form: form, rank: 1)
      form.update_attribute(:root_id, root.id)
      evaluator.question_types.each_with_index do |qts, index|
        if qts.kind_of?(Array) 
          group = QingGroup.create!(parent: form.root_group, form: form, rank: index+1)
          qts.each_with_index { |qt, i| create_question(qt, form.mission, evaluator.option_names, evaluator.use_multilevel_option_set, i+1, group, form) }
        else
          create_question(qts, form.mission, evaluator.option_names, evaluator.use_multilevel_option_set, index+1, form.root_group, form)
        end         
      end
    end
    
    mission { is_standard ? nil : get_mission }
    sequence(:name) { |n| "Sample Form #{n}" }



    # A form with different question types.
    # We hardcode names to make expectations easier, since we assume no more than one sample form per test.
    # TODO: Remove, can't find this used any more?
    factory :sample_form do
      name 'Sample Form'
      questionings do
        [
          # Single level select_one question.
          build(:questioning, mission: mission, form: nil,
            question: build(:question, mission: mission, name: 'Question 1', hint: 'Hint 1',
              qtype_name: 'select_one', option_set: build(:option_set, name: 'Set 1'))),

          # Multilevel select_one question.
          build(:questioning, mission: mission, form: nil,
            question: build(:question, mission: mission, name: 'Question 2', hint: 'Hint 2',
              qtype_name: 'select_one', option_set: build(:option_set, name: 'Set 2', multi_level: true))),

          # Integer question.
          build(:questioning, mission: mission, form: nil,
            question: build(:question, mission: mission, name: 'Question 3', hint: 'Hint 3',
              qtype_name: 'integer'))
        ]
      end
    end
  end
end
