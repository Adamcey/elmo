# ELMO - Secure, robust, and versatile data collection.
# Copyright 2011 The Carter Center
#
# ELMO is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# ELMO is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with ELMO.  If not, see <http://www.gnu.org/licenses/>.
# 
require 'language_list'
module ApplicationHelper
  include LanguageList
   
  # renders the flash message and any form errors for the given activerecord object
  def flash_and_form_errors(object = nil)
    render("layouts/flash", :flash => flash, :object => object)
  end
  
  # applies any customizations to automatically generated form error messages
  # called from layouts/flash
  def fix_error_messages(msgs)
    msgs.gsub!("Answers are invalid", "One or more answers are invalid")
    msgs.gsub!("@ please.", "@")
    msgs.gsub!("look like an email address.", "look like an email address")
    msgs
  end
  
  # renders a link only if the current user is authorized for the specified action
  def link_to_if_auth(label, url, action, object = nil, *args)
    authorized?(:action => action, :object => object) ? link_to(label, url, *args) : ""
  end
  
  # same as link_to_if_auth but for button_to
  def button_to_if_auth(label, url, action, object = nil, *args)
    authorized?(:action => action, :object => object) ? button_to(label, url, *args) : ""
  end
  
  # draws a basic form for the given object
  # THIS IS THE OLD WAY
  def basic_form(obj, &block)
    form_for(obj) do |f|
      f.mode = form_mode
      # get the fields spec
      spec = block.call(f)
      # if fields doesn't have sections, create one big section 
      spec[:sections] = [{:fields => spec[:fields]}] unless spec[:sections]
      # render the form and return it
      render("layouts/basic_form", :f => f, :spec => spec, :obj => obj)
    end
  end
  
  # THIS IS THE NEW WAY
  def nice_form_for(obj)
    form_for(obj) do |f|
      # set form mode
      f.mode = form_mode
      yield(f)
    end
  end
  
  # gets the mode a form should be displayed in: one of new, edit, or show
  def form_mode
    {:new => :new, :create => :new, :edit => :edit, :update => :edit, :show => :show}[controller.action_name.to_sym]
  end
  
  def form_field(f, method, options = {})
    if options[:type] == :hidden
      f.hidden_field(method)
    elsif options[:type] == :submit
      f.submit(f.object.class.human_attribute_name("submit_" + (f.object.new_record? ? "new" : "edit")), :class => "submit")
    else
      content_tag("div", :class => "form_field", :id => method) do
        label_str = options[:label] || f.object.class.human_attribute_name(method)
        label_html = (label_str + (options[:required] ? " #{reqd_sym}" : "")).html_safe
        label = f.label(method, label_html, :class => "main")
        
        # temporarily force show mode if requested
        old_f_mode = f.mode
        f.mode = :show if options[:force_show_mode]
        
        field = content_tag("div", :class => "form_field_control") do
          
          # if this is a partial
          if options[:partial]
            render(options[:partial], (options[:locals] || {}).merge({:form => f, :method => method}))
          else
            case options[:type]
            when nil, :text
              f.text_field(method, {:class => "text"}.merge(options[:size] ? {:size => options[:size]} : {}))
            when :check_box
              # if we are in show mode, show 'yes' or 'no' instead of checkbox
              if f.mode == :show
                content_tag("strong"){f.object.send(method) ? "Yes" : "No"}
              else
                f.check_box(method)
              end
            when :radio_buttons
              options[:options].collect{|o| f.radio_button(method, o, :class => "radio") + o}.join("&nbsp;&nbsp;").html_safe
            when :textarea 
              f.text_area(method)
            when :password
              f.password_field(method)
            when :country
              country_select(f.object.class.name.downcase, method, nil)
            when :select
              f.select(method, options[:options], :include_blank => options[:blank_text] || true)
            when :datetime
              f.datetime_select(method, :ampm => true, :order => [:month, :day, :year], :default => options[:default])
            when :birthdate
              f.date_select(method, :start_year => Time.now.year - 110, :end_year => Time.now.year - 18, 
                :include_blank => true, :order => [:month, :day, :year], :default => nil)
            when :timezone
              f.time_zone_select(method)
            end
          end
          
        end
        
        # revert to old form mode
        f.mode = old_f_mode
        
        tip = t(method, :scope => [:activerecord, :tips, f.object.class.model_name.i18n_key]).gsub("\n", "<br/>").html_safe
        details = content_tag("div", :class => "form_field_details"){options[:details] || tip}
        details + label + field + "<div class=\"space_line\"></div>".html_safe
      end
    end
  end
  
  def form_submit_button(f, options = {})
    # wrap in form_buttons if not wrapped
    return form_buttons{form_submit_button(f, options.merge(:multiple => true))} unless options[:multiple]
    label = options.delete(:label) || "Submit"
    f.submit(label, options.merge(:class => "submit"))
  end
  
  def form_buttons(&block)
    buttons = capture{block.call}
    content_tag("div", :class => "form_buttons"){buttons + tag("br")}
  end
  
  def form_subheading(label)
    content_tag("div", :class => "form_subheading"){label}
  end
  
  # renders the standard 'required' symbol, which is an asterisk
  def reqd_sym(condition = true)
    (condition ? '<div class="reqd_sym">*</div>' : '').html_safe
  end
  
  def action_icon(action, options = {})
    suffix = options[:no_label] ? "-no-label" : ""
    image_tag("action-icons/#{action}#{suffix}.png")
  end
  
  # assembles links for the basic actions in an index table (show edit and destroy)
  def action_links(obj, options)
    destroy_warning = options[:destroy_warning] || "Are you sure?"
    route_key = obj.class.model_name.route_key.singularize
    links = %w(show edit destroy).collect do |action|
      options[:exclude] = [options[:exclude]] unless options[:exclude].is_a?(Array)
      next if options[:exclude] && options[:exclude].include?(action.to_sym)
      img = action_icon(action)
      key = "#{obj.class.table_name}##{action}"
      case action
      when "show"
        link_to_if_auth(img, send("#{route_key}_path", obj), key, obj, :title => "View")
      when "edit"
        link_to_if_auth(img, send("edit_#{route_key}_path", obj), key, obj, :title => "Edit")
      when "destroy"
        link_to_if_auth(img, obj, key, obj, :method => :delete, :confirm => destroy_warning, :title => "Delete")
      end
    end.compact
    links.join("").html_safe
  end
  
  # joins a set of links together with pipe characters, ignoring any blank ones
  # for use with link_to_if_auth
  def join_links(*links)
    links.reject{|l| l.blank?}.join(" | ").html_safe
  end
  
  # creates a link to a batch operation
  # options include :action (e.g. forms#add_questions), :id, :format, :name (name of the link)
  def batch_op_link(options)
    url_bits = {}
    url_bits[:controller], url_bits[:action] = options[:action].split("#")
    url_bits[:id] = options[:id] if options[:id]
    url_bits[:format] = options[:format] if options[:format]
    path = url_for(url_bits)
    button_to_if_auth(options[:name], "#", options[:action], nil, 
      :onclick => "batch_submit({path: '#{path}', confirm: '#{options[:confirm]}'}); return false;",
      :class => "batch_op_link")
  end
  
  # creates a link to select all the checkboxes in an index table
  def select_all_link
    button_to("Select All", "#", :onclick => "batch_select_all(); return false", :id => "select_all_link")
  end
  
  # renders an index table for the given class and list of objects
  def index_table(klass, objects)
    # get links from class' helper
    links = send("#{klass.table_name}_index_links", objects)

    # if there are any batch links, insert the 'select all' link
    batch_ops = !links.reject{|l| !l.match(/class="batch_op_link"/)}.empty?
    links.insert(0, select_all_link) if batch_ops
    
    # render, getting fields and checking if there are no objects at all
    render("layouts/index_table",
      :klass => klass,
      :objects => objects,
      :paginated => objects.respond_to?(:total_entries),
      :links => join_links(*links.flatten),
      :fields => send("#{klass.table_name}_index_fields"),
      :batch_ops => batch_ops
    )
  end
  
  def loading_indicator(options = {})
    content_tag("div", :class => "loading_indicator loading_indicator#{options[:floating] ? '_floating' : '_inline'}") do
      image_tag("load-ind-small#{options[:header] ? '-header' : ''}.gif", :style => "display: none", :id => "loading_indicator" + 
        (options[:id] ? "_#{options[:id]}" : ""))
    end
  end
  
  # returns a set of [name, id] pairs for the given objects
  # defaults to using .name and .id, but other methods can be specified, including Procs
  # if :tags is set, returns the <option> tags instead of just the array
  def sel_opts_from_objs(objs, options = {})
    # set default method names
    id_m = options[:id_method] ||= "id"
    name_m = options[:name_method] ||= "name"
    
    # get array of arrays
    arr = objs.collect do |o| 
      # get id and name array
      id = id_m.is_a?(Proc) ? id_m.call(o) : o.send(id_m)
      name = name_m.is_a?(Proc) ? name_m.call(o) : o.send(name_m)
      [name, id]
    end
    
    # wrap in tags if requested
    options[:tags] ? options_for_select(arr) : arr
  end
  
  # renders a collection of objects, including a boilerplate form and calls to the appropriate JS
  def collection_form(params)
    render(:partial => "layouts/collection_form", :locals => params)
  end
  
  def language_name(code)
    LANGS[code]
  end
end
