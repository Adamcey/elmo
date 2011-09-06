module QuestioningsHelper
  def format_questionings_field(qing, field)
    case field
    when "rank"
      controller.action_name == "show" ? 
        qing.rank : 
        text_field_tag("rank[#{qing.id}]", qing.rank, :onchange => "form_recalc_ranks(this)")
    when "code", "name", "type" then format_questions_field(qing.question, field)
    when "condition?" then qing.has_condition? ? "Yes" : "No"
    when "required?", "hidden?" then qing.send(field) ? "Yes" : "No"
    when "actions"
      exclude = qing.published? || controller.action_name == "show" ? [:edit, :destroy] : []
      action_links(qing, :destroy_warning => "Are you sure you want to remove question '#{qing.code}' from this form", :exclude => exclude)
    else qing.send(field)
    end
  end
  
  def questionings_index_links(qings)
    links = []
    if controller.action_name == "edit"
      links << link_to("Add questions", choose_questions_path(:form_id => @form.id))
      if qings.size > 0
        links << batch_op_link(:name => "Remove selected",
          :confirm => "Are you sure you want to remove these ### question(s) from the form?",
          :action => "forms#remove_questions", :id => @form.id)
      end
    end
    links
  end
  
  def questionings_index_fields
    %w[rank code name type condition? required? hidden? actions]
  end
end
