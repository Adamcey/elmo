module OptionsHelper
  def options_index_links(options)
    [link_to_if_auth("Add new option", new_option_path, "options#create")]
  end
  def options_index_fields
    %w[name value published? actions]
  end
  def format_options_field(option, field)
    case field
    when "name" then option.name_en
    when "published?" then option.published? ? "Yes" : "No"
    when "actions"
      exclude = option.published? ? [:destroy] : []
      action_links(option, :destroy_warning => "Are you sure you want to delete option '#{option.name_en}'?", 
        :exclude => exclude)
    else option.send(field)
    end
  end
end
