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
class OptionSetsController < ApplicationController
  def index
    @sets = apply_filters(OptionSet).for_index
  end
  
  def new
    @set = OptionSet.for_mission(current_mission).new
    render_form
  end
  
  def edit
    @set = OptionSet.find(params[:id])
    render_form
  end

  def show
    @set = OptionSet.find(params[:id])
    render_form
  end

  def destroy
    @set = OptionSet.find(params[:id])
    begin 
      flash[:success] = @set.destroy && "Option set deleted successfully." 
    rescue
      if $!.is_a?(InvalidAssociationDeletionError)
        flash[:error] = "You can't delete option set '#{@set.name}' because one or more responses are associated with it."
      else
        flash[:error] = $!.to_s
      end
    end
    redirect_to(:action => :index)
  end
  
  def create; crupdate; end
  def update; crupdate; end

  private
    def crupdate
      action = params[:action]
      @set = action == "create" ? OptionSet.for_mission(current_mission).new : OptionSet.find(params[:id])
      begin
        @set.update_attributes!(params[:option_set])
        flash[:success] = "Option set #{action}d successfully."
        redirect_to(:action => :index)
      rescue ActiveRecord::RecordInvalid, InvalidAssociationDeletionError
        @set.errors.add(:base, $!.to_s) if $!.is_a?(InvalidAssociationDeletionError)
        render_form
      end
    end
    
    def render_form
      @options = restrict(Option).all
      render(:form)
    end
end
