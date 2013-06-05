require 'open-uri'
require 'uri'
class Sms::Adapters::IntelliSmsAdapter < Sms::Adapters::Adapter

  # checks if this adapter recognizes an incoming http receive request
  def self.recognize_receive_request?(request)
    # if the params from, text, msgid, and sent are all in the request params, its ours!
    %w(from text msgid sent) - request.request_parameters.keys == []
  end
  
  def service_name
    @service_name ||= "IntelliSms"
  end
  
  def deliver(message)
    # let the superclass do the sanity checks
    super
    
    # build the URI the request
    uri = build_uri(:deliver, :to => message.to.join(','), :text => ActiveSupport::Inflector.transliterate(message.body))
    
    # don't send in test mode
    unless Rails.env == "test"
      response = send_request(uri)
      
      # get any errors that the service returned
      errors = response.split("\n").reject{|l| !l.match(/ERR:/)}.join("\n")
      raise Sms::Error.new(errors) unless errors.blank?
    end
    
    # if we get to this point, it worked
    return true
  end
  
  def receive(params)
    [Sms::Message.create(:from => "+#{params['from']}", :body => params["text"], :sent_at => Time.zone.parse(params["sent"], :adapter_name => service_name))]
  end
  
  # check_balance returns the balance string
  def check_balance
    send_request(build_uri(:balance)).split(":")[1].to_i
  end
  
  private
    # builds uri based on given action and query string params. returns URI object.
    def build_uri(action, params = {})
      raise Sms::Error.new("No username is configured for the IntelliSms adapter") if configatron.intellisms_username.blank?
      raise Sms::Error.new("No password is configured for the IntelliSms adapter") if configatron.intellisms_password.blank?
    
      page = case action
      when :deliver then "sendmsg"
      when :balance then "getbalance"
      else
        raise ArgumentError.new
      end
      
      # add credentials
      params[:username] = configatron.intellisms_username
      params[:password] = configatron.intellisms_password
    
      uri = URI("http://www.intellisoftware.co.uk/smsgateway/#{page}.aspx")
      uri.query = URI.encode_www_form(params)
      return uri
    end
end