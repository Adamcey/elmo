# Elmo - Secure, robust, and versatile data collection.
# Copyright 2011 The Carter Center
#
# Elmo is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Elmo is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Elmo.  If not, see <http://www.gnu.org/licenses/>.
# 
class ResponsesController < ApplicationController
  def create
    # if this is a submission from ODK collect
    if request.format == Mime::XML
      if request.method == "HEAD"
        # just render the 'no content' status since that's what odk wants!
        render(:nothing => true, :status => 204)
      elsif upfile = params[:xml_submission_file]
        begin
          contents = upfile.read
          Rails.logger.debug("Form data: " + contents)
          Response.create_from_xml(contents, current_user)
          render(:nothing => true, :status => 201)
        rescue ArgumentError, ActiveRecord::RecordInvalid
          msg = "Form submission error: #{$!.to_s}"
          Rails.logger.error(msg)
          render(:nothing => true, :status => 500)
        end
      end
    else
      crupdate
    end
  end
  
  def index
    respond_to do |format|
      format.html do
        @responses = load_objects_with_subindex(Response)
        @js << "responses_index"
        render(:partial => "table_only", :locals => {:responses => @responses}) if ajax_request?
      end
      format.csv do
        require 'csv'
        perm_condition = Permission.select_conditions(:user => current_user, :controller => "responses", :action => "index")
        @responses = Response.flattened(:conditions => perm_condition)
        render_csv("responses-#{Time.zone.now.strftime('%Y-%m-%d-%H%M')}")
      end
    end
  end
  
  def new
    form = Form.find(params[:form_id]) rescue nil
    flash[:error] = "You must choose a form to edit." and redirect_to(:action => :index) unless form
    @resp = Response.new(:form => form)
    set_js
  end
  
  def edit
    @resp = Response.find_eager(params[:id])
    set_js
  end
  
  def show
    @resp = Response.find_eager(params[:id])
  end
  
  def update
    crupdate
  end
  
  def destroy
    @resp = Response.find(params[:id])
    begin flash[:success] = @resp.destroy && "Response deleted successfully." rescue flash[:error] = $!.to_s end
    redirect_to(:action => :index)
  end
  
  private
    def crupdate
      action = params[:action]
      # source is web, 
      params[:response][:source] = "web" if action == "create"
      params[:response][:modifier] = "web"
      # find or create the response
      @resp = action == "create" ? Response.new : Response.find(params[:id])
      # set user_id if this is an observer
      @resp.user = current_user if current_user.is_observer?
      # try to save
      begin
        @resp.update_attributes!(params[:response])
        flash[:success] = "Response #{action}d successfully."
        redirect_to(:action => :index)
      rescue ActiveRecord::RecordInvalid
        set_js
        render(:action => action == "create" ? :new : :edit)
      end
    end
    
    def set_js
      @js << 'places'
    end
end
