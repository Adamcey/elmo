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
class ApplicationController < ActionController::Base
  require 'authlogic'
  include ActionView::Helpers::AssetTagHelper
  
  protect_from_forgery
  rescue_from(Exception, :with => :notify_error)
  before_filter(:set_default_title)
  before_filter(:mailer_set_url_options)

  # user/user_session stuff
  before_filter(:basic_auth_for_xml)
  before_filter(:get_session_user_mission)
  before_filter(:authorize)
  
  # this goes last as the timezone can depend on the user
  before_filter(:set_timezone)
  
  # allow the current user and mission to be accessed
  attr_reader :current_user, :current_mission
  
  # make these methods visible in the view
  helper_method :current_user, :current_mission, :authorized?
  
  
  # hackish way of getting the route key identical to what would be returned by model_name.route_key on a model
  def route_key
    self.class.name.underscore.gsub("/", "_").gsub(/_controller$/, "")
  end
  
  protected
    
    # Renders a file with the browser-appropriate MIME type for CSV data.
    # @param [String] filename The filename to render. If not specified, the contents of params[:action] is used.
    def render_csv(filename = nil)
      filename ||= params[:action]
      filename += '.csv'

      if request.env['HTTP_USER_AGENT'] =~ /msie/i
        headers['Pragma'] = 'public'
        headers["Content-type"] = "text/plain" 
        headers['Cache-Control'] = 'no-cache, must-revalidate, post-check=0, pre-check=0'
        headers['Content-Disposition'] = "attachment; filename=\"#{filename}\"" 
        headers['Expires'] = "0" 
      else
        headers["Content-Type"] ||= 'text/csv'
        headers["Content-Disposition"] = "attachment; filename=\"#{filename}\"" 
      end

      render(:layout => false)
    end
    
    # Loads the user-specified timezone from configatron, if one exists
    def set_timezone
      Time.zone = configatron.timezone.to_s if configatron.timezone?
    end
    
    def mailer_set_url_options
      ActionMailer::Base.default_url_options[:host] = request.host_with_port
    end
    
    def set_default_title
      action = {"index" => "", "new" => "Create ", "create" => "Create ", "edit" => "Edit ", "update" => "Edit "}[action_name] || ""
      obj = controller_name.gsub("_", " ").ucwords
      obj = obj.singularize unless action_name == "index"
      @title = action + obj
    end
    
    # loads objects selected with a batch form
    def load_selected_objects(klass)
      params[:selected].keys.collect{|id| klass.find_by_id(id)}.compact
    end

    # notifies the webmaster of an error in production mode
    def notify_error(exception)
      if Rails.env == "production"
        begin
          AdminMailer.error(exception, session.to_hash, params, request.env).deliver 
        rescue 
          logger.error("ERROR SENDING ERROR NOTIFICATION: #{$!.to_s}")
        end
      end
      # still show error page
      raise exception
    end
    
    # don't count automatic timer-based requests for resetting the logout timer
    # all automatic timer-based should set the 'auto' parameter
    def last_request_update_allowed?
      params[:auto].nil?
    end
    
    # checks if the current request was made by ajax
    def ajax_request?
      request.env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest' || params[:ajax]
    end
    

    ##############################################################################
    # AUTHENTICATION AND USER SESSION METHODS
    ##############################################################################
    
    def basic_auth_for_xml
      # if the request format is XML and there is no user, we should require basic auth
      # this just sets the current user for this one request. no user session is created.
      if request.format == Mime::XML
        @current_user = authenticate_or_request_with_http_basic{|login, password| User.find_by_credentials(login, password)}
      end
    end
    
    def get_session_user_mission
      # get the current user session from authlogic
      @current_user_session = UserSession.find

      # look up the current user from the user session
      # we use a find call to the User class so that we can do eager loading
      @current_user = (sess = @current_user_session) && (user = sess.user) && User.includes(:assignments).find(user.id)
    
      # look up the current mission based on the current user
      @current_mission = @current_user ? @current_user.current_mission : nil
      
      # if a mission was found, notify the settings class
      Setting.mission_was_set(@current_mission) if @current_mission
    end
    
    # tasks that should be run after the user successfully logs in OR successfully resets their password
    # returns false if no further stuff should happen (redirect), true otherwise
    def post_login_housekeeping
      # get the session
      @user_session = UserSession.find
      
      # reset the perishable token for security's sake
      @user_session.user.reset_perishable_token!
      
      # pick a mission
      @user_session.user.set_current_mission
      
      # if no mission, error
      if @user_session.user.current_mission.nil?
        flash[:error] = "You are not assigned to any missions."
        @user_session.destroy
        redirect_to(new_user_session_path)
        return false
      end
      
      return true
    end
    
    
    ##############################################################################
    # AUTHORIZATION METHODS
    ##############################################################################
    
    def authorize
      # make sure user has permissions
      begin
        Permission.authorize(:user => current_user, :mission => current_mission, :controller => route_key, :action => action_name, :request => params)
        return true
      rescue PermissionError
        # if request is for the login page, just go to welcome page with no flash
        if controller_name == "user_sessions" && action_name == "new"
          redirect_to("/")
        # if request is for the logout page, just go to the login page with no flash
        elsif controller_name == "user_sessions" && action_name == "destroy"
          redirect_to(new_user_session_path)
        else
          store_location unless ajax_request?
          # if the user needs to login, send them to the login page
          flash[:error] = $!.to_s
          flash[:error].match(/must login/) ? redirect_to_login : render("permissions/no", :status => :unauthorized)
        end
        # halt the rest of the action
        return false
      end
    end 
    
    def authorized?(params)
      return Permission.authorized?(params.merge(:user => current_user, :mission => current_mission))
    end
    
    def restrict(rel)
      Permission.restrict(rel, :user => current_user, :mission => current_mission)
    end
    
    # applies search, permissions, and pagination
    # each of these can be turned off by specifying e.g. :pagination => false in the options array
    def apply_filters(rel, options = {})
      klass = rel.respond_to?(:klass) ? rel.klass : rel

      # apply search
      @search = Search::Search.new(:class_name => klass.name, :str => params[:search])
      rel = @search.apply(rel) unless options[:search] == false
      
      # apply permissions
      rel = restrict(rel) unless options[:permissions] == false

      # apply pagination and return
      rel = rel.paginate(:page => params[:page]) unless params[:page].nil? || options[:pagination] == false
      
      # return the relation
      rel
    end
    
    
    ##############################################################################
    # METHODS FOR REDIRECTING THE USER
    ##############################################################################
    
    # redirects to the login page
    # or if this is an ajax request, returns a 401 unauthorized error
    # in the latter case, the script should catch this error and redirect to the login page itself
    def redirect_to_login
      if ajax_request? 
        flash[:error] = nil
        render(:text => "LOGIN_REQUIRED", :status => 401)
      else
        redirect_to(new_user_session_path)
      end
    end
    
    def store_location  
      session[:return_to] = request.fullpath  
    end
    
    def forget_location
      session[:return_to] = nil
    end
  
    def redirect_back_or_default(default)  
      redirect_to(session[:return_to] || default)  
      forget_location
    end
end
