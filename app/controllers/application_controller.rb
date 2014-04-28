class ApplicationController < ActionController::Base
  require 'authlogic'
  include ActionView::Helpers::AssetTagHelper

  # makes sure authorization is performed in each controller
  check_authorization

  # handle general errors nicely
  rescue_from(Exception, :with => :notify_error)

  # handle authorization errors nicely
  rescue_from CanCan::AccessDenied do |exception|
    # set flag for tests to check
    @access_denied = true

    # log to debug log
    Rails.logger.debug("ACCESS DENIED on #{exception.action} #{exception.subject.inspect} #{exception.message} " +
      "(Current Mission: #{current_mission.try(:name)}; Current Role: #{current_user.try(:role, current_mission)})")

    # if not logged in, offer a login page
    if !current_user
      # don't put an error message if the request was for the home page
      flash[:error] = I18n.t("unauthorized.must_login") unless request.path == "/"
      redirect_to_login
    # else if there was just a mission change, we need to handle specially
    elsif params[:missionchange]
      # if the request was a CRUD, try redirecting to the index, or root if no permission
      if Ability::CRUD.include?(exception.action) && current_ability.can?(:index, exception.subject.class)
        redirect_to(:controller => controller_name, :action => :index)
      else
        redirect_to(mission_root_url)
      end
    # else redirect to welcome page with error
    else
      redirect_to(root_url, :flash => { :error => exception.message })
    end
  end

  protect_from_forgery
  before_filter(:set_locale)
  before_filter(:mailer_set_url_options)

  before_filter(:get_user)
  before_filter(:get_mission)
  before_filter(:protect_admin_mode)

  # store index page numbers if this is an index action
  before_filter(:remember_page_number, :only => :index)

  before_filter(:load_settings)

  attr_reader :current_user, :current_mission

  helper_method :current_user, :current_mission, :accessible_missions, :ajax_request?, :admin_mode?, :index_url_with_page_num

  # hackish way of getting the route key identical to what would be returned by model_name.route_key on a model
  def route_key
    self.class.name.underscore.gsub("/", "_").gsub(/_controller$/, "")
  end

  def default_url_options(options={})
    { :locale => I18n.locale, :mode => params[:mode], :mission_id => current_mission.try(:compact_name) }
  end

  # mailer is for some reason too stupid to figure these out on its own
  def mailer_set_url_options
    # copy options from the above method, and add a host option b/c mailer is especially stupid
    default_url_options.merge(:host => request.host_with_port).each_pair do |k,v|
      ActionMailer::Base.default_url_options[k] = v
    end
  end

  def appropriate_root_path
    current_mission ? mission_root_path(:mode => 'm', :mission_id => current_mission.compact_name) : basic_root_path
  end

  protected

    # sets the locale based on the locale param (grabbed from the path by the router)
    def set_locale
      I18n.locale = params[:locale] || I18n.default_locale
    end

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

    # removes any non-filename-safe characters from a string so that it can be used in a filename
    def sanitize_filename(filename)
      sanitized = filename.strip
      sanitized.gsub!(/^.*(\\|\/)/, '')
      # strip out non-ascii characters
      sanitized.gsub!(/[^0-9A-Za-z.\-]/, '_')
      sanitized
    end

    # Loads the user-specified timezone from configatron, if one exists
    def set_timezone
      Time.zone = configatron.timezone.to_s if configatron.timezone?
    end

    # loads objects selected with a batch form
    def load_selected_objects(klass)
      params[:selected].keys.collect{|id| klass.find_by_id(id)}.compact
    end

    # notifies the webmaster of an error in production mode
    def notify_error(exception, options = {})
      if Rails.env == "production"
        begin
          AdminMailer.error(exception, session.to_hash, params, request.env, current_user).deliver
        rescue
          logger.error("ERROR SENDING ERROR NOTIFICATION: #{$!.to_s}: #{$!.message}\n#{$!.backtrace.to_a.join("\n")}")
        end
      end
      # still show error page unless requested not to
      raise exception unless options[:dont_re_raise]
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

    # applies search and pagination
    # each of these can be turned off by specifying e.g. :pagination => false in the options array
    def apply_filters(rel, options = {})
      klass = rel.respond_to?(:klass) ? rel.klass : rel

      # apply search
      begin
        @search = Search::Search.new(:str => params[:search])
        @search.qualifiers = klass.search_qualifiers(:mission => current_mission)
        rel = @search.apply(rel) unless options[:search] == false
      rescue Search::ParseError
        flash.now[:error] = "#{t('search.search_error')}: #{$!}"
      end

      # apply pagination and return
      rel = rel.paginate(:page => params[:page]) unless params[:page].nil? || options[:pagination] == false

      # return the relation
      rel
    end

    # loads settings for the mission, or no mission (admin mode), into configatron
    def load_settings
      # if there is a logged in user, we load settings saved in DB
      if current_user
        @setting = Setting.load_for_mission(current_mission)

      # otherwise we just spin up a dummy default setting obj and don't save it
      else
        @setting = Setting.load_default
      end
    end

    def current_mode
      @current_mode ||= case params[:mode]
      when 'admin' then 'admin'
      when 'm' then 'mission'
      else 'basic'
      end
    end

    def admin_mode?
      current_mode == 'admin'
    end

    def mission_mode?
      current_mode == 'mission'
    end

    def basic_mode?
      current_mode == 'basic'
    end

    # makes sure admin_mode is not true if user is not admin
    def protect_admin_mode
      if admin_mode? && cannot?(:view, :admin_mode)
        params[:mode] = nil
        raise CanCan::AccessDenied.new("not authorized for admin mode", :view, :admin_mode)
      end
    end

    # attempts to get the model class controlled by this controller
    # not always appropriate
    def model_class
      @model_class ||= controller_name.classify.constantize
    end

    ##############################################################################
    # AUTHENTICATION AND USER SESSION METHODS
    ##############################################################################

    # gets the user and mission from the user session if they're not already set
    def get_user
      # if the request format is XML we should use basic auth
      @current_user = if request.format == Mime::XML
        # authenticate with basic
        user = authenticate_with_http_basic do |login, password|
          # use eager loading to optimize things a bit
          User.includes(:assignments).find_by_credentials(login, password)
        end

        # if authentication not successful, fail
        return request_http_basic_authentication if !user

        user
      else
        # get the current user session from authlogic
        user_session = UserSession.find
        user = user_session.nil? ? nil : user_session.user

        # look up the current user from the user session
        # we use a find call to the User class so that we can do eager loading
        User.includes(:assignments).find(user.id) unless user.nil?
      end
    end

    def get_mission
      # if we're in admin mode, the current mission is nil and we need to set the user's current mission to nil also
      if mission_mode?
        # look up the current mission based on the mission_id
        @current_mission = Mission.with_compact_name(params[:mission_id])
        # save the current mission in the session so we can remember it if the user goes into admin mode
        session[:last_mission_id] = @current_mission.try(:id)
      else
        @current_mission = nil
      end
    end

    # get the current user's ability. not cached because it's volatile!
    def current_ability
      Ability.new(:user => current_user, :mode => current_mode, :mission => current_mission)
    end

    # gets the missions accessible to the current ability, or [] if no current user
    # sorts result
    def accessible_missions
      Mission.accessible_by(current_ability, :switch_to)
    end

    # resets the Rails session but preserves the :return_to key
    # used for security purposes
    def reset_session_preserving_return_to
      tmp = session[:return_to]
      reset_session
      session[:return_to] = tmp
    end

    # tasks that should be run after the user successfully logs in OR successfully resets their password
    # returns false if no further stuff should happen (redirect), true otherwise
    def post_login_housekeeping
      # get the session
      @user_session = UserSession.find

      # reset the perishable token for security's sake
      @user_session.user.reset_perishable_token!

      return true
    end

    ##############################################################################
    # METHODS FOR REDIRECTING THE USER
    ##############################################################################

    # redirects to the login page
    # or if this is an ajax request, returns a 401 unauthorized error (but this should never happen)
    # in the latter case, the script should catch this error and redirect to the login page itself
    def redirect_to_login
      if ajax_request?
        flash[:error] = nil
        render(:text => "LOGIN_REQUIRED", :status => 401)
      else
        store_location
        redirect_to(login_url)
      end
    end

    def store_location
      # if the request is a GET, then store as normal
      session[:return_to] = if request.get?
        request.fullpath
      # otherwise, store the referrer (if defined), since it doesn't make sense to store a URL for a different method
      elsif request.referrer
        request.referrer
      # otherwise store nothing
      else
        nil
      end
    end

    def forget_location
      session[:return_to] = nil
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      forget_location
    end

    ##############################################################################
    # METHODS FOR ASSISTING BASIC CRUD OPERATIONS IN DESCENDANT CONTROLLERS
    ##############################################################################

    # attempts to destroy obj and add an i18n'd success message to flash
    # on error, translates the error message and adds that to flash
    def destroy_and_handle_errors(obj, options = {})
      begin
        obj.send(options[:but_first]) if options[:but_first]
        obj.destroy
        flash[:success] = "#{obj.class.model_name.human} #{t('errors.messages.deleted_successfully')}"
      rescue DeletionError
        flash[:error] = t($!.to_s, :scope => [:activerecord, :errors, :models, obj.class.model_name.i18n_key], :default => t("errors.messages.generic_delete_error"))
      end
    end

    # sets a success message based on the given object
    def set_success(obj)
      # get verb (past tense) based on action
      verb = t("common.#{params[:action]}d").downcase

      # build and set the message
      flash[:success] = "#{obj.class.model_name.human.ucwords} #{verb} #{t('common.successfully').downcase}."
    end

    # sets a success message and redirects
    def set_success_and_redirect(obj, options = {})
      # redirect to index_url_with_page_num by default
      options[:to] ||= index_url_with_page_num

      # save the object id in the flash in case the view wants to have some fun with it
      flash[:modified_obj_id] = obj.id

      # if options[:to] is a symbol, we really mean :action => xxx
      options[:to] = {:action => options[:to]} if options[:to].is_a?(Symbol)

      set_success(obj)

      # do the redirect
      redirect_to(options[:to])
    end

    # gets the url to an index action, ensuring the appropriate page is returned to
    # ctlr - the controller whose index should be used. defaults to current controller
    def index_url_with_page_num(ctlr = nil)
      url_for(:controller => ctlr || controller_name, :action => :index, :page => get_last_page_number)
    end

    # remembers the last visited page number for each controller and mission
    def remember_page_number
      if params[:page]
        session[:last_page_numbers] ||= {}
        session[:last_page_numbers][last_page_number_hash_key] = params[:page]
      end
    end

    # builds a simple hash key for remembering page numbers
    def last_page_number_hash_key
      controller_name + current_mission.try(:id).to_s
    end

    def get_last_page_number
      if session[:last_page_numbers]
        session[:last_page_numbers][last_page_number_hash_key]
      else
        nil
      end
    end

    # gets the request's referrer without the query string
    def referrer_without_query_string
      ref = URI(request.referrer)
      ref.to_s.gsub("?#{ref.query}", '')
    end
end
