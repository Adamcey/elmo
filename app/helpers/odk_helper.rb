module OdkHelper
  IR_QUESTION = "ir01"   # incomplete response question
  IR_CODE     = "ir02"   # incomplete response code

  # given a Subquestion object, builds an odk <input> tag
  # calls the provided block to get the tag content
  def odk_input_tag(qing, subq, opts, &block)
    opts ||= {}

    opts[:ref] = "/data/#{subq.odk_code}"
    opts[:rows] = 5 if subq.qtype_name == "long_text"
    opts[:query] = multi_level_option_nodeset_ref(qing, subq) if !subq.first_rank? && subq.qtype.name == 'select_one'
    content_tag(odk_input_tagname(subq), opts, &block)
  end

  def odk_input_tagname(subq)
    if subq.qtype.name == 'select_one' && subq.first_rank?
      :select1
    elsif subq.qtype.name == 'select_multiple'
      :select
    else
      :input
    end
  end

  # if a question is required, then determine the appropriate value based off of if the form allows incomplete responses
  def required_value(form)
    # if form allows incompletes, question is required only if the answer to 'are there missing answers' is 'no'
    form.allow_incomplete? ? "selected(/data/#{IR_QUESTION}, 'no')" : "true()"
  end

  def appearance(grid_mode, label_row)
    return 'label' if label_row
    return 'list-nolabel' if grid_mode
  end

  # generator for binding portion of xml.
  # note: _required is used to get around the 'required' html attribute
  def question_binding(form, qing, subq)
    tag(:bind, {
      'nodeset' => "/data/#{subq.odk_code}",
      'type' => binding_type_attrib(subq),
      '_required' => qing.required? && subq.first_rank? ? required_value(form) : nil,
      'relevant' => qing.has_condition? ? qing.condition.to_odk : nil,
      'constraint' => subq.odk_constraint,
      'jr:constraintMsg' => subq.min_max_error_msg,
     }.reject{|k,v| v.nil?}).gsub(/_required=/, 'required=').html_safe
  end

  # note: _readonly is used to get around the 'readonly' html attribute
  def note_binding(group)
    tag(:bind, {
      'nodeset' => "/data/grp-header#{group.id}",
      '_readonly' => "true()",
      'type' => "string"
    }.reject{|k,v| v.nil?}).gsub(/_readonly=/, 'readonly=').html_safe
  end

  def binding_type_attrib(subq)
    # ODK wants non-first-level selects to have type 'string'
    subq.first_rank? ? subq.odk_name : 'string'
  end

  # binding for incomplete response question
  # note: required is an html attribute. the gsub gets around this processing branch
  def ir_question_binding(form)
    tag("bind", {
      'nodeset' => "/data/#{IR_QUESTION}",
      'required' => "true()",
      'type' => "select1",
     }.reject{|k,v| v.nil?}).gsub(/"required"/, '"true()"').html_safe
  end

  # binding for incomplete response code
  # note: required is an html attribute. the gsub gets around this processing branch
  def ir_code_binding(form)
    tag("bind", {
      'nodeset' => "/data/#{IR_CODE}",
      'required' => "true()",
      'relevant' => "selected(/data/#{IR_QUESTION}, 'yes')",
      'constraint' => ". = '#{form.override_code}'",
      'type' => "string",
     }.reject{|k,v| v.nil?}).gsub(/"required"/, '"true()"').html_safe
  end

  # For the given subquestion, returns an xpath expression for the itemset tag nodeset attribute.
  # E.g. instance('os16')/root/item or
  #      instance('os16')/root/item[parent_id=/data/q2_1] or
  #      instance('os16')/root/item[parent_id=/data/q2_2]
  def multi_level_option_nodeset_ref(qing, cur_subq)
    filter = if cur_subq.first_rank?
      ''
    else
      code = cur_subq.odk_code(previous: true)
      "[parent_id=/data/#{code}]"
    end
    "instance('os#{qing.option_set_id}')/root/item#{filter}"
  end

  # Returns <text> tags for all first-level options.
  def odk_option_translations(form, lang)
    odk_options = form.all_first_level_option_nodes.collect do |on|
      content_tag(:text, id: "on#{on.id}") do
        content_tag(:value) do
          on.option.name(lang, strict: false)
        end
      end
    end
    odk_options.reduce(&:concat)
  end

  # Tests if all items in the group are Questionings with the same type and option set.
  def grid_mode?(items)
    # more than one question is needed for grid mode
    false unless items.size > 1

    items.all? do |i|
      i.is_a?(Questioning) &&
      i.qtype_name == 'select_one' &&
      i.option_set == items[0].option_set &&
      !i.multi_level?
    end
  end

  def empty_qing_group?(subtree)
    subtree.keys.empty?
  end

  def organize_qing_groups(descendants)
    QingGroupOdkPartitioner.new(descendants).fragment();
  end
end
