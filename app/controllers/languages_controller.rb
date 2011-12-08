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
class LanguagesController < ApplicationController
  
  def index
    @languages = Language.sorted(:paginate => true, :page => params[:page])
  end
  def new
    @language = Language.default
    @title = "Add Language"
  end
  def edit
    @language = Language.find(params[:id])
  end
  def create
    @language = Language.new(params[:language])
    if @language.save
      flash[:success] = "Language created successfully."
      redirect_to(:action => :index)
    else
      render(:action => :new)
    end
  end
  def update
    @language = Language.find(params[:id])
    if @language.update_attributes(params[:language])
      flash[:success] = "Language updated successfully."
      redirect_to(:action => :index)
    else
      render(:action => :edit)
    end
  end
  def destroy
    @language = Language.find(params[:id])
    begin flash[:success] = @language.destroy && "Language deleted successfully." rescue flash[:error] = $!.to_s end
    redirect_to(:action => :index)
  end
end
