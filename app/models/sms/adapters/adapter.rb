# models a generic sms adapter. should be subclassed.
require 'net/http'
class Sms::Adapters::Adapter

  # checks if this adapter recognizes an incoming http receive request
  def self.recognize_receive_request?(request)
    false
  end
  
  # delivers a message to one or more recipients
  # raises an error if no recipients, wrong direction, or message empty
  # should also raise an error if the provider returns an error code
  # returns true if all goes well
  # 
  # message   the message to be sent
  def deliver(message)
    # error if no recipients or message empty
    raise Sms::Error.new("Message has no recipients") if message.to.blank?
    raise Sms::Error.new("Message body is empty") if message.body.blank?
  end
  
  # recieves one or more sms messages
  # returns an array of Sms::Message objects
  # 
  # params  the parameters sent from the sms provider
  def receive(params)
    
  end
  
  # returns the number of sms credits available in the provider account
  # should be overridden if this feature is available
  def check_balance
    raise NotImplementedError
  end
  
  protected
    
    # sends request to given uri, handles errors, or returns response text if success
    def send_request(uri)
      # create http handler
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 30 # in seconds
      http.read_timeout = 30 # in seconds

      # create request
      request = Net::HTTP::Get.new(uri.request_uri)
      
      # send request and catch errors
      begin
        response = http.request(request)
      rescue Timeout::Error
        raise Sms::Error.new("Error contacting #{service_name} (Timeout)")
      rescue
        raise Sms::Error.new("Error contacting #{service_name} (#{$!.class.name}: #{$!.to_s})")
      end
      
      # return body if it's a clean success, else error
      if response.is_a?(Net::HTTPSuccess)
        return response.body
      else
        raise Sms::Error.new("Error contacting #{service_name} (#{response.class.name})")
      end
    end
end