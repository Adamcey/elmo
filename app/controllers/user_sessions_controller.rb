class UserSessionsController < ApplicationController

  # don't need to authorize here (except for destroy action) because anyone can see log in page
  skip_authorization_check

  before_filter(:ensure_logged_out, :only => [:new, :destroy, :logged_out])

  def new
    @user_session = UserSession.new
  end

  def create
    # reset the session for security purposes
    reset_session_preserving_return_to

    @user_session = UserSession.new(params[:user_session])

    # if the save is successful, the user is logged in automatically
    if @user_session.save
      post_login_housekeeping
    else
      flash[:error] = @user_session.errors.full_messages.join(",")
      redirect_to(:action => :new)
    end
  end

  def destroy
    forget_location
    redirect_to(logged_out_url)
  end

  # shows a simple 'you are logged out' page
  def logged_out
  end
end
