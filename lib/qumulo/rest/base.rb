require "json"
require "net/http"
require "net/https"
require "openssl"
require "qumulo/rest/exception"
require "qumulo/rest/client"
module Qumulo::Rest

  # == Class Description
  # All other RESTful resource classes inherit from this class.
  # This class takes care of the following:
  # * DSL for defining RESTful resource
  # * HTTP request/response handling
  # * Request signing
  # * Response Parsing
  #
  class Base

    # --------------------------------------------------------------------------
    # Resource DSL
    #

    # === Description
    # Indicates the format of URL path to locate a single resource.
    #
    # path "/conf/network"  # singleton resource for network config
    # path "/users/:id"     # user resource located by :id
    #
    # Note that if we can locate a single resource by "/users/:id",
    # it is assumed that we can get all users by "/users/".
    #
    def self.path(path_spec)
      # here, @path_spec is not meant to be a class instance variable of Base
      # class; but it is a class instance variable of the drived class.
      @path_spec = path_spec
    end

    # === Description
    # This method can be used against a drived class to get the @path_spec
    # instance variable set using .path method above.
    #
    def self.get_path
      @path_spec
    end

    # --------------------------------------------------------------------------
    # Constructor
    #

    # === Description
    # Take attributes and stores as instance variable.
    # Also initializes instance variables, as follows.
    #
    # === Instance Variables
    # @attrs:: Hash object represents the up-to-date resource state
    # @error:: stores any error details returned by the server
    # @response:: last received Net::HTTP::Response object
    # @created:: object was created on the client side (as opposed to fetched)
    #
    def initialize(attrs)
      # convert symbol keys to string keys
      @attrs = {}
      attrs.each do |k, v|
        @attrs[k.to_s] = v
      end
      @error = nil
      @response = nil
      @created = true
    end

    # --------------------------------------------------------------------------
    # HTTP Handling
    #

    # === Description
    # Convert a path that may contain variable parts to a fully resolved path
    # string.
    #
    # === Returns
    # A path String with all the variable parts resolved.
    #
    def resolved_path
      resolved = []
      path = self.class.get_path
      path.split('/').each do |part|
        resolved_part = (part =~ /^:/) ?
                        @attrs[part.replace(/^:/, '')].to_s : part
        if (part != "" and resolved_part == "")
          throw UrlError.new("Cannot resolve #{part} in path #{path}", self)
        end
        resolved << resolved_part
      end
      resolved.join('/')
    end

    # === Description
    # If response is error, set @error to be either Hash object if JSON
    # parse is successful, or a status message String if JSON parse is
    # not successful.
    #
    # If response is not an error, clear @error, parse response body,
    # and set @attrs accordingly.
    #
    # === Parameters
    # response:: Net::HTTPResponse object
    #
    # === Throws
    # JSON::ParserError if response does not contain valid JSON
    #
    def process_response(response)
      @response = response
      if response.is_a?(Net::HTTPError)
        begin
          @error = JSON.parse(response.body)
        rescue JSON::ParserError
          @error = response.msg
        end
      else
        @error = nil
        puts response.body
        @attrs = JSON.parse(response.body)
      end
    end

    # === Description
    # Perform GET request. If GET is successful, response object
    # is stored in @response, @error is cleared, and the response
    # body is parsed by either Resource or Collection class,
    # and replaces @attrs. If GET fails, @error instance is populated.
    #
    # === Parameters
    # opts:: Hash object to control request details
    # opts[:client]:: client object to use. If not given, default client
    #                 stored in Qumulo::Rest::Client class will be used.
    #                 Unless you are talking to 2 clusters at the same time,
    #                 you don't need to pass this option.
    # opts[:timeout]:: client timeout value in seconds. If not given, the
    #                 default timeout value from Qumulo::Rest::Client will
    #                 be used.
    # opts[:query]:: Hash object representing query string parameters to pass
    #
    def http_get(opts = {})
    end

    # === Description
    # Perform POST request. If POST is successful, response object
    # is stored in @response, @error is cleared, and the response
    # body is parsed by either Resource or Collection class,
    # and replaces @attrs. If POST fails, @error instance is populated.
    #
    # === Parameters
    # opts:: Hash object to control request details
    # opts[:client]:: client object to use. If not given, default client
    #                 stored in Qumulo::Rest::Client class will be used.
    #                 Unless you are talking to 2 clusters at the same time,
    #                 you don't need to pass this option.
    # opts[:timeout]:: client timeout value in seconds. If not given, the
    #                 default timeout value from Qumulo::Rest::Client will
    #                 be used.
    # opts[:no_sign]:: when set to true, we skip signing the request.
    #                 This option is only useful when performing login.
    # opts[:query]:: Hash object representing query string parameters to pass
    #
    def http_post(opts = {})
      post = Net::HTTP::Post.new(resolved_path)
      post.content_type = "application/json"
      post.body = JSON.generate(@attrs)
      client = opts[:client] || Client.default
      http = Net::HTTP.new(client.host, client.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = http.start {|cx| cx.request(post)}
      process_response(response)
    end

  end

end
