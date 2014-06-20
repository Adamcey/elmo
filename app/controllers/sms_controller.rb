# handles incoming sms messages from various providers
class SmsController < ApplicationController
  # load resource for index
  load_and_authorize_resource :class => "Sms::Message", :only => :index

  # don't need authorize for this controller. authorization is handled inside the sms processing machinery.
  skip_authorization_check :only => :create

  # disable csrf protection for this stuff
  protect_from_forgery :except => :create

  def index
    # cancan load_resource messes up the inflection so we need to create smses from sms
    @smses = @sms.newest_first.paginate(:page => params[:page], :per_page => 50)
  end

  def create
    # get the mission from the params. if not found raise an error (we need the mission)
    mission = Mission.find_by_compact_name(params[:mission])
    raise Sms::Error.new("Mission not specified") if mission.nil?

    # Copy settings from the message's mission so that settings are available below.
    mission.setting.load

    @incoming_adapter = Sms::Adapters::Factory.new.create_for_request(params)

    raise Sms::Error.new("no adapters recognized this receive request") if @incoming_adapter.nil?

    @incoming = @incoming_adapter.receive(request.POST)

    @incoming.update_attributes(:mission => mission)

    # Store the reply in an instance variable so the functional test can access them
    @reply = Sms::Handler.new.handle(@incoming)

    # Expose this to tests even if we don't use it.
    @outgoing_adapter = configatron.outgoing_sms_adapter

    if @reply
      deliver_reply(@reply) # This method does an appropriate render
    else
      render :nothing => true, :status => 204 # No Content
    end
  end

  private

    def deliver_reply(reply)
      # Set the incoming_sms_number as the from number, if we have one
      reply.update_attributes(:from => configatron.incoming_sms_number) unless configatron.incoming_sms_number.blank?

      if @incoming_adapter.reply_style == :via_adapter
        @outgoing_adapter.deliver(reply)
        render :text => 'REPLY_SENT'
      else # reply via response
        render :text => reply.body
      end
    end
end
