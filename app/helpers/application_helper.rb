module ApplicationHelper
  def show_flash_and_form_errors(object = nil)
    render("layouts/flash", :flash => flash, :object => object)
  end
  def link_to_if_auth(label, url, action, object = nil, *args)
    authorized?(:action => action, :object => object) ? link_to(label, url, *args) : ""
  end
  def basic_form(obj, &block)
    form_for(obj) do |f|
      fields = block.call(f)
      render("layouts/basic_form", :f => f, :fields => fields, :obj => obj)
    end
  end
  def join_links(*links)
    links.reject{|l| l.blank?}.join(" | ").html_safe
  end
end
