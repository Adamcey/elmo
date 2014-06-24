class Sms::Adapters::FrontlineSmsAdapter < Sms::Adapters::Adapter

  def self.recognize_receive_request?(params)
    %w(from text frontline) - params.keys == []
  end

  def self.can_deliver?
    false
  end

  def service_name
    @service_name ||= "FrontlineSms"
  end

  def reply_style
    :via_response
  end

  def deliver(message)
    raise NotImplementedError
  end

  def receive(params)
    Sms::Message.create(
      :direction => 'incoming',
      :from => params['from'],
      :body => params['text'],
      :sent_at => Time.zone.now, # Frontline doesn't supply this
      :adapter_name => service_name)
  end
end