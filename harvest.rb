# Insert your subdomain i.e. subdomain.harvestapp.com
SUBDOMAIN        = 'CHANGEME'

# Your email. Note that features hidden from non-administrator
# accounts on the WEB UI will be inaccessible in the API as well. The
# full API is available to users with admin privileges only!
ACCOUNT_EMAIL    =  'MUST_HAVE_ACCESS_TO_DATA_YOU_WANT@example.com'

# Your password. Harvest uses HTTP Basic Auth.
ACCOUNT_PASSWORD =  'correcthorsebatterystaple'

# Your application should send an unique User Agent value out of
# politeness.
USER_AGENT       = 'test'

# Business accounts have ssl support enabled. Set this to false if your
# WEB UI is accessible via http:// instead of https://. Note that
# Harvest will redirect you to the proper protocol regardless of
# this. You just need to handle the redirection pragmatically. This
# sample does this, your implementation should save the last known
# protocol to avoid increased latency.
HAS_SSL          = true



########################################################################
#
# Define a basic client.
#

require 'base64'
require 'bigdecimal'
require 'date'
require 'net/http'
require 'net/https'
require 'time'

class Harvest

  def initialize
    @company             = SUBDOMAIN
    @preferred_protocols = [HAS_SSL, ! HAS_SSL]
    connect!
  end

  # HTTP headers you need to send with every request.
  def headers
    {
      "Accept"        => "application/json",

      # Promise to send XML.
      "Content-Type"  => "application/xml; charset=utf-8",

      # All requests will be authenticated using HTTP Basic Auth, as
      # described in rfc2617. Your library probably has support for
      # basic_auth built in, I've passed the Authorization header
      # explicitly here only to show what happens at HTTP level.
      "Authorization" => "Basic #{auth_string}",

      # Tell Harvest a bit about your application.
      "User-Agent"    => USER_AGENT
    }
  end

  def auth_string
    Base64.encode64("#{ACCOUNT_EMAIL}:#{ACCOUNT_PASSWORD}").delete("\r\n")
  end

  def request path, method = :get, body = ""
    response = send_request( path, method, body)
    if response.class < Net::HTTPSuccess
      # response in the 2xx range
      on_completed_request
      return response
    elsif response.class == Net::HTTPServiceUnavailable
      # response status is 503, you have reached the API throttle
      # limit. Harvest will send the "Retry-After" header to indicate
      # the number of seconds your boot needs to be silent.
      raise "Got HTTP 503 three times in a row" if retry_counter > 3
      sleep(response['Retry-After'].to_i + 5)
      request(path, method, body)
    elsif response.class == Net::HTTPFound
      # response was a redirect, most likely due to protocol
      # mismatch. Retry again with a different protocol.
      @preferred_protocols.shift
      raise "Failed connection using http or https" if @preferred_protocols.empty?
      connect!
      request(path, method, body)
    else
      dump_headers = response.to_hash.map { |h,v| [h.upcase,v].join(': ') }.join("\n")
      raise "#{response.message} (#{response.code})\n\n#{dump_headers}\n\n#{response.body}\n"
    end
  end

  private

  def connect!
    port = has_ssl ? 443 : 80
    @connection             = Net::HTTP.new("#{@company}.harvestapp.com", port)
    @connection.use_ssl     = has_ssl
    @connection.verify_mode = OpenSSL::SSL::VERIFY_NONE if has_ssl
  end

  def has_ssl
    @preferred_protocols.first
  end

  def send_request path, method = :get, body = ''
    case method
    when :get
      @connection.get(path, headers)
    when :post
      @connection.post(path, body, headers)
    when :put
      @connection.put(path, body, headers)
    when :delete
      @connection.delete(path, headers)
    end
  end

  def on_completed_request
    @retry_counter = 0
  end

  def retry_counter
    @retry_counter ||= 0
    @retry_counter += 1
  end

end
########################################################################
