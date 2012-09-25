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
class FormsController < ApplicationController
  
  def index
    respond_to do |format|
      # render normally if html
      format.html do
        @forms = apply_filters(Form).with_form_type.all
        render(:index)
      end
      
      # get only published forms and render openrosa if xml requested
      format.xml do
        @forms = Form.published.with_form_type
        render_openrosa
      end
    end
  end
  
  def new
    @form = Form.for_mission(current_mission).new
    render_form
  end
  
  def edit
    @form = Form.with_questions.find(params[:id])
    render_form
  end
  
  def show
    @form = Form.with_questions.find(params[:id])

    # add to download count if xml
    @form.add_download if request.format.xml? 
    
    respond_to do |format|
      # for html, render the printable partial if requested, otherwise render the form
      format.html{params[:print] ? render_printable : render_form}
      
      # for xml, render openrosa
      format.xml{render_openrosa}
    end
  end
  
  def destroy
    @form = Form.find(params[:id])
    begin flash[:success] = @form.destroy && "Form deleted successfully." rescue flash[:error] = $!.to_s end
    redirect_to(:action => :index)
  end
  
  def publish
    @form = Form.find(params[:id])
    verb = @form.published? ? "unpublish" : "publish"
    begin
      @form.toggle_published
      dl = verb == "unpublish" ? " The download count has also been reset." : ""
      flash[:success] = "Form #{verb}ed successfully." + dl
    rescue
      flash[:error] = "There was a problem #{verb}ing the form (#{$!.to_s})."
    end
    # redirect to form edit
    redirect_to(:action => :index)
  end
  
  def add_questions
    # load the form
    @form = Form.find(params[:id])
    
    # load the question objects
    questions = load_selected_objects(Question)

    # raise error if no valid questions (this should be impossible)
    raise "No valid questions given." if questions.empty?
    
    # add questions to form and try to save
    @form.questions += questions
    if @form.save
      flash[:success] = "Questions added successfully"
    else
      flash[:error] = "There was a problem adding the questions (#{@form.errors.full_messages.join(';')})"
    end
    
    # redirect to form edit
    redirect_to(edit_form_path(@form))
  end
  
  
  def remove_questions
    # load the form
    @form = Form.find(params[:id])
    # get the selected questionings
    qings = load_selected_objects(Questioning)
    # destroy
    begin
      @form.destroy_questionings(qings)
      flash[:success] = "Questions removed successfully."
    rescue
      flash[:error] = "There was a problem removing the questions (#{$!.to_s})."
    end
    # redirect to form edit
    redirect_to(edit_form_path(@form))
  end
  
  def update_ranks
    redirect_to(edit_form_path(@form))
  end
  
  def clone
    @form = Form.find(params[:id])
    begin
      @form.duplicate
      flash[:success] = "Form '#{@form.name}' cloned successfully."
    rescue
      raise $!
      flash[:error] = "There was a problem cloning the form (#{$!.to_s})."
    end
    redirect_to(:action => :index)
  end
  
  def create; crupdate; end
  
  def update; crupdate; end
  
  private
  
    def crupdate
      action = params[:action]
      @form = action == "create" ? Form.for_mission(current_mission).new : Form.find(params[:id], :include => {:questionings => :condition})
      
      # set submitter if user doesn't have permission to do so
      @form.user_id = current_user.id unless Permission.can_choose_form_submitter?(current_user, current_mission)
      
      begin
        # save basic attribs
        @form.attributes = params[:form]
        
        # update ranks if provided
        if params[:rank]
          # build hash of questioning ids to ranks
          new_ranks = {}; params[:rank].each_pair{|id, rank| new_ranks[id] = rank}
          
          # update (possibly raising condition ordering error)
          @form.update_ranks(new_ranks)
        end
        
        # save everything and redirect
        @form.save!
        flash[:success] = "Form #{action}d successfully."
        redirect_to(edit_form_path(@form))

      # handle problem with conditions
      rescue ConditionOrderingError
        @form.errors.add(:base, "The new rankings invalidate one or more conditions")
        render_form
      
      # handle other validation errors  
      rescue ActiveRecord::RecordInvalid
        render_form
      end
    end
    
    # adds the appropriate headers for openrosa content
    def render_openrosa
      render(:content_type => "text/xml")
      response.headers['X-OpenRosa-Version'] = "1.0"
    end
    
    # renders the printable partial
    def render_printable
      render(:partial => "printable", :layout => false, :locals => {:form => @form})
    end
    
    def render_form
      @form_types = apply_filters(FormType)
      render(:form)
    end
end
