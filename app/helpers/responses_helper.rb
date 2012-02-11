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
module ResponsesHelper
  def responses_index_fields
    %w[form_name place submitter observation_time submission_time age reviewed? actions]
  end
  def format_responses_field(resp, field)
    case field
    when "observation_time" then resp.observed_at && resp.observed_at.strftime("%Y-%m-%d %l:%M%p") || ""
    when "submission_time" then resp.created_at && resp.created_at.strftime("%Y-%m-%d %l:%M%p") || ""
    when "age" then resp.created_at && time_ago_in_words(resp.created_at).gsub("about ", "") || ""
    when "reviewed?" then resp.reviewed? ? "Yes" : "No"
    when "place" then resp.place ? truncate(resp.place.full_name, :length => 40) : ""
    when "actions"
      # we don't need to authorize these links b/c for responses, if you can see it, you can edit it.
      # the controller actions will still be auth'd
      by = resp.user ? " by #{resp.user.name}" : ""
      from = resp.place ? " from #{resp.place.long_name}" : ""
      action_links(resp, :destroy_warning => "Are you sure you want to delete the response#{by}#{from}? You won't be able to undelete it!")
    else resp.send(field)
    end
  end
  def responses_index_links(responses)
    links = []
    # only add the create response link if there are any published forms
    unless (sel_opt = Form.select_options).empty?
      mini_form = form_tag(new_response_path, :method => :get, :id => "form_chooser", :style => "display: none") do
          select_tag(:form_id, options_for_select(sel_opt), :include_blank => "Select a published form...") +
          submit_tag("Go")
      end
      links << link_to_if_auth("Create new response", "#", "responses#create", nil, 
        :onclick => "$('form_chooser').show(); return false") + mini_form
    end
    unless responses.empty?
      #links << link_to_if_auth("Export all to CSV", responses_path(:format => :csv), "responses#index", nil)
    end
    links
  end
  # calls the answer fields template for the given response
  def answers_subform(answers)
    content_tag("table", :class => "form answers") do
      content_tag("tr"){content_tag("th", :colspan => 3){"Answers"}} +
        render(:partial => "answer", :collection => answers)
    end
  end
end
