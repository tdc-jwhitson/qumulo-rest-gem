require "json"
require "net/http"
require "net/https"
require "qumulo/rest/validator"

module Qumulo::Rest
  class Http
    include Validator

    # --------------------------------------------------------------------------
    # HTTP Handling
    #

    # === Description
    # Create an http request to call HTTP verbs on.  This object stores some HTTP
    # options, such as timeout or authorization
    #
    # === Parameters
    # host:: Qumulo cluster address
    # port:: Qumulo cluster REST API port address (e.g. 8000)
    # timeout:: timeout value in seconds
    # bearer_token:: token to use to authorize against Qumulo cluster
    #
    def initialize(host, port, timeout, bearer_token = nil)
      @host = host # validated already in client
      @port = port # validated already in client
      @open_timeout = validated_positive_int(:timeout, timeout)
      @read_timeout = validated_positive_int(:timeout, timeout)
      @bearer_token = bearer_token
    end

    # === Description
    # Send HTTP request, and return the response from the server.
    #
    # === Parameters
    # request:: instance of Net::HTTP::{Post,Put,Get,Delete}
    #
    # === Returns
    # If successfulm a Hash object containing:
    #  {
    #    :response => <Net::HTTPResponse object>,
    #    :attrs => <Hash object representing resource attributes>
    #  }
    #
    # If failed, a Hash object containing:
    #  {
    #    :response => <Net::HTTPResponse object>,
    #    :code => <Integer representation of status code>,
    #    :error => <Hash object representing error structure>
    #  }
    #
    # === Raises
    # JSON::ParserError if successful response does not contain valid JSON
    #
    def http_execute(request)
      request.content_type = "application/json"
      request["Authorization"] = @bearer_token if @bearer_token
      http = Net::HTTP.new(@host, @port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      response = http.start {|cx| cx.request(request)}
      result = {:response => response, :code => response.code.to_i}
      if response.is_a?(Net::HTTPError)
        begin
          result[:error] = JSON.parse(response.body)
        rescue JSON::ParserError
          result[:error] = { :message => response.msg }
        end
      else
        result[:body] = response.body # for debugging
        result[:attrs] = JSON.parse(response.body)
      end
      result
    end

    # === Description
    # Perform POST request.
    #
    # === Parameters
    # path:: URI path, including query string parameters
    # attrs:: Hash object containing key-value pairs representing resource
    #
    # === Returns
    # result Hash object
    #
    def post(path, attrs)
      post = Net::HTTP::Post.new(path)
      post.body = JSON.generate(attrs)
      http_execute(post)
    end

    # === Description
    # Perform PUT request.
    #
    # === Parameters
    # path:: URI path, including query string parameters
    # attrs:: Hash object containing key-value pairs representing resource
    #
    # === Returns
    # result Hash object
    #
    def put(path, attrs)
      put = Net::HTTP::Put.new(path)
      put.body = JSON.generate(attrs)
      http_execute(put)
    end

    # === Description
    # Perform GET request.
    #
    # === Parameters
    # path:: URI path, including query string parameters
    #
    # === Returns
    # result Hash object
    #
    def get(path)
      http_execute(Net::HTTP::Get.new(path))
    end

    # === Description
    # Perform DELETE request against a resource.
    #
    # === Parameters
    # path:: URI path, including query string parameters
    #
    # === Returns
    # result Hash object
    #
    def delete(path)
      http_execute(Net::HTTP::DELETE.new(path))
    end

  end
end

