class ResponsesController < ApplicationController
  def create
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
        render(:partial => "table_only", :locals => {:responses => @responses}) if params[:table_only]
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
        redirect_to(edit_response_path(@resp))
      rescue ActiveRecord::RecordInvalid
        set_js
        render(:action => action == "create" ? :new : :edit)
      end
    end
    
    def set_js
      @js << 'places'
    end
end
