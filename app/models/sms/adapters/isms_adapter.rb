require 'uri'
require 'net/http'
require 'xml'
class Sms::Adapters::IsmsAdapter < Sms::Adapters::Adapter
  
  # checks if this adapter recognizes an incoming http receive request
  def self.recognize_receive_request?(request)
    # just check the user agent
    request.headers["User-Agent"] =~ /MultiModem iSMS/
  end

  def service_name
    "Isms"
  end
  
  def deliver(sms)
    # let the superclass do the sanity checks
    super
    
    # get list of numbers
    # isms wants numbers wrapped in quotes
    numbers = sms.to.map{|num| "\"#{num}\""}.join(",")
    
    # build the URI for the request (numbers must be enclosed in double quotes for some reason)
    # TEMPORARY added transliterate to sms.body to remove accents
    uri = build_uri(:deliver, :to => numbers, :text => ActiveSupport::Inflector.transliterate(sms.body))
    
    # don't send in test mode
    unless Rails.env == "test"
      response = send_request(uri)

      # if response looks like an error, try to decipher it
      if response =~ /Err: (\d+)/
        code = $1
        
        case code
        when "601"
          raise Sms::Error.new("Authentication error connecting to #{service_name}")
        else 
          raise Sms::Error.new("Error sending message using #{service_name} (Code #{code})")
        end
      end
    end

    # if we get to this point, it worked, so return true
    return true
  end
  
  # receives message params and turns into an array of messages
  def receive(params)
    # first authenticate the request so that not just anybody can send messages to our API
    unless params["username"] == configatron.isms_incoming_username && params["password"] == configatron.isms_incoming_password
      raise Sms::Error.new("Authentication error receiving from #{service_name}") 
    end
    
    smses = []
    
    # now parse the xml
    begin
      doc = XML::Parser.string(params["XMLDATA"]).parse
    
      # loop over each MessageNotification node
      messages = doc.root.find("./MessageNotification")

      # get the info for each message
      messages.each do |message|
        from = message.find_first("SenderNumber").content
        body = message.find_first("Message").content
        date = message.find_first("Date").content
        time = message.find_first("Time").content
        
        # isms should be in UTC. date format is YY/MM/DD. we add 20 to be safe. time is HH:MM:SS.
        sent_at = Time.zone.parse("20#{date} #{time} UTC")
        
        smses << Sms::Message.create(:from => from, :body => body, :sent_at => sent_at)
      end
      
    rescue XML::Parser::ParseError
      raise Sms::Error.new("Error parsing xml from #{service_name}")
    end
    
    return smses
  end
  
  private
    # builds uri based on given action and query string params. returns URI object.
    def build_uri(action, params = {})
      raise Sms::Error.new("No hostname is configured for the Isms adapter") if configatron.isms_hostname.blank?
      raise Sms::Error.new("No username is configured for the Isms adapter") if configatron.isms_username.blank?
      raise Sms::Error.new("No password is configured for the Isms adapter") if configatron.isms_password.blank?
      
      page = case action
      when :deliver then "sendmsg"
      end
      
      params[:user] = configatron.isms_username
      params[:passwd] = configatron.isms_password
      params[:cat] = 1
      
      uri = URI("http://#{configatron.isms_hostname}/#{page}.html")
      uri.query = URI.encode_www_form(params)
      return uri
    end
end