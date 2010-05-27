require 'net/http'
require 'uri'

module Shorty
  ShortyError       = Class.new(StandardError)
  URLConflict       = Class.new(ShortyError)
  URLFormatError    = Class.new(ShortyError)
  InvalidResponse   = Class.new(ShortyError)
  KeyRequiredError  = Class.new(ArgumentError)
  
  class Client
    attr_reader :error
    
    def initialize(end_point, &block)
      @uri = URI.parse(end_point)
      yield self if block_given?
    end
    
    # Return nil/false if a key couldn't be generated
    def shorten(url, key=nil)
      begin
        shorten!(url, key)
      rescue => e
        nil
      end
    end
    
    # Raise an exception of the url couldn't be shortened
    def shorten!(url, key=nil)
      begin
        key ? named_url(url, key) : autoname_url(url)
      rescue => e
        @error = e and raise
      end
    end
    
    # Gets a new key that was generated by Shorty.
    def key
      Net::HTTP.get(@uri.host, "#{@uri.request_uri}key", @uri.port)
    end
    
  protected
    # PUT the url and a key to Shorty. This is used if you want to specify th
    # short url key.
    def named_url(url, key)
      raise KeyRequiredError("Key required for named short URLs") unless key
      request('PUT', "#{@uri.request_uri}#{key}", url)
    end
    
    # POST the long url to the server and automatically generate a key. Use
    # if you don't know or care about the shortened URL key.
    def autoname_url(url)
      request('POST', @uri.request_uri, url)
    end
    
    # A more abstraction HTTP request for Shorty
    def request(method, request_uri, long_url)
      Net::HTTP.start(@uri.host, @uri.port) do |http|
        headers = { 'Content-Type' => 'text/plain' }
        response = http.send_request(method, request_uri, long_url, headers)
        process_response(response)
      end
    end
    
    # Processes HTTP responses for Shorty
    def process_response(response)
      case response
        when Net::HTTPFound, Net::HTTPCreated
          response['Location']
        when Net::HTTPConflict
          raise URLConflict
        when Net::HTTPNotAcceptable
          raise URLFormatError
        else
          raise InvalidResponse.new("Invalid Shorty Response Code: #{response.code} #{response.message}")
      end
    end
  end
end