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
class UserSessionsController < ApplicationController
  
  def new
    @title = "Login"
    @user_session = UserSession.new
  end
  
  def create
    reset_session
    @user_session = UserSession.new(params[:user_session])
    
    # if the save is successful, the user is logged in automatically
    if @user_session.save
      
      # do post login housekeeping
      return unless post_login_housekeeping
      
      flash[:success] = "Login successful"
      redirect_back_or_default(root_path)
    else
      flash[:error] = @user_session.errors.full_messages.join(",")
      redirect_to(:action => :new)
    end
  end
  
  def destroy
    @user_session = UserSession.find  
    @user_session.destroy
    forget_location
    redirect_to(:action => :logged_out)
  end
  
  def logged_out
    @title = "Logged Out"
  end
end
