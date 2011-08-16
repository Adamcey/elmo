module ApplicationHelper
  def show_flash_and_form_errors(object = nil)
    render("layouts/flash", :flash => flash, :object => object)
  end
  def link_to_if_auth(label, url, action, object = nil, *args)
    authorized?(:action => action, :object => object) ? link_to(label, url, *args) : ""
  end
  # draws a basic form for the given object
  def basic_form(obj, &block)
    form_for(obj) do |f|
      f.mode = controller.action_name.to_sym
      # get the fields spec
      spec = block.call(f)
      # if fields doesn't have sections, create one big section 
      spec[:sections] = [{:fields => spec[:fields]}] unless spec[:sections]
      # render the form and return it
      render("layouts/basic_form", :f => f, :spec => spec, :obj => obj)
    end
  end
  def join_links(links, separator = " | ")
    links.reject{|l| l.blank?}.join(separator).html_safe
  end
  def place_field(place, place_lookup)
    render("places/place_field", :place => place, :place_lookup => place_lookup)
  end
  def reqd_sym(condition = true)
    (condition ? '<div class="reqd_sym">*</div>' : '').html_safe
  end
  def action_links(obj, options)
    destroy_warning = options[:destroy_warning] || "Are you sure?"
    klass = obj.class.name.underscore
    links = %w(show edit destroy).collect do |action|
      options[:exclude] = [options[:exclude]] unless options[:exclude].is_a?(Array)
      next if options[:exclude] && options[:exclude].include?(action.to_sym)
      img = image_tag("#{action}.png")
      key = "#{obj.class.table_name}##{action}"
      case action
      when "show"
        link_to_if_auth(img, send("#{klass}_path", obj), key, obj, :title => "View")
      when "edit"
        link_to_if_auth(img, send("edit_#{klass}_path", obj), key, obj, :title => "Edit")
      when "destroy"
        link_to_if_auth(img, obj, key, obj, :method => :delete, :confirm => destroy_warning, :title => "Delete")
      end
    end.compact
    links.join("").html_safe
  end
  def batch_op_links(*options)
    links = options.collect{|o| batch_op_link(o)}.reject{|l| l.blank?}
    links.insert(0, select_all_link) unless links.empty?
    links
  end
  def batch_op_link(options)
    url_bits = {}
    url_bits[:controller], url_bits[:action] = options[:action].split("#")
    url_bits[:id] = options[:id] if options[:id]
    url_bits[:format] = options[:format] if options[:format]
    path = url_for(url_bits)
    link_to_if_auth(options[:name], "#", options[:action], nil, 
      :onclick => "batch_submit({path: '#{path}', confirm: '#{options[:confirm]}'}); return false;")
  end
  def select_all_link
    link_to("Select All", "#", :onclick => "batch_select_all(); return false", :id => "select_all_link")
  end
  def fix_error_messages(msgs)
    msgs.gsub("Answers are invalid", "One or more answers are invalid").gsub("@ please.", "@").gsub("look like an email address.", "look like an email address")
  end
end
