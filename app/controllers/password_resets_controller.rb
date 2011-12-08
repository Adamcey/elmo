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
class PasswordResetsController < ApplicationController
  
  before_filter(:load_user_using_perishable_token, :only => [:edit, :update])

  def new
    @title = "Reset Password"
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
      @user = User.find_by_perishable_token(params[:id])  
      unless @user
        flash[:error] = "We're sorry, but we could not locate your account. " +  
          "If you are having issues try copying and pasting the URL " +  
          "from your email into your browser or restarting the " +  
          "reset password process."  
        redirect_to(root_url)
      end
    end
end
