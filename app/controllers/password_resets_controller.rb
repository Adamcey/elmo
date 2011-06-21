class PasswordResetsController < ApplicationController
  before_filter :require_no_user
  before_filter :load_user_using_perishable_token, :only => [:edit, :update]

  def new
    render
  end  

  def edit
    @title = "Reset Password"
  end

  def create  
    @user = User.find_by_email(params[:email])  
    if @user  
      @user.deliver_password_reset_instructions!  
      flash[:success] = "Instructions to reset your password have been emailed to you. Please check your email."  
      redirect_to(root_url)
    else  
      flash[:error] = "No user was found with that email address"  
      redirect_to(:action => :new)
    end
  end
  
  def update
    User.ignore_blank_passwords = false
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    if @user.save
      flash[:success] = "Password successfully updated"  
      User.ignore_blank_passwords = true
      redirect_to(root_url)
    else
      @title = "Reset Password"
      @user.password = nil
      @user.password_confirmation = nil
      render(:action => :edit)  
    end  
  end  

  private  
    def load_user_using_perishable_token
      Rails.logger.debug(params.to_yaml)
      @user = User.find_using_perishable_token(params[:id])  
      unless @user
        flash[:error] = "We're sorry, but we could not locate your account. " +  
          "If you are having issues try copying and pasting the URL " +  
          "from your email into your browser or restarting the " +  
          "reset password process."  
        redirect_to(root_url)
      end
    end
end
