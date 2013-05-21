class BroadcastsController < ApplicationController
  # authorization via cancan
  load_and_authorize_resource
  
  # this method is special
  skip_load_and_authorize_resource :only => :new_with_users
  
  def index
    # apply pagination
    @broadcasts = @broadcasts.paginate(:page => params[:page], :per_page => 50)
  end
  
  def new
    flash[:success] = "To send a broadcast, first select the recipients below, and then click 'Send Broadcast'."
    redirect_to(users_path)
  end
  
  # Displays a new broadcast form with the given recipients.
  # @param [Hash] selected A Hash user ids as keys, referring to recipients of the broadcast.
  def new_with_users
    # load the user objects
    users = User.accessible_by(current_ability).where(:id => params[:selected].keys).all
        
    # raise error if no valid users (this should be impossible)
    raise "No valid users given." if users.empty?
    
    # create a new Broadcast
    @broadcast = Broadcast.accessible_by(current_ability).new(:recipients => users)

    # call authorize so no error
    authorize!(:create, @broadcast)
    
    begin
      # get credit balance
      @balance = Smser.check_balance
    rescue NotImplementedError
      # don't need to do anything here
    rescue
      # log all other errors
      logger.error("SMS balance request error: #{$!}")
    end
    
    render(:form)
  end
  
  def show
    render(:form)
  end
  
  def create
    if @broadcast.update_attributes(params[:broadcast])
      if @broadcast.send_errors
        flash[:error] = "Error sending broadcast (see below)."
      else
        flash[:success] = "Broadcast sent successfully."
      end
      redirect_to(broadcast_path(@broadcast))
    else
      render(:form)
    end
  end
end
