require 'qumulo/rest/validator'
module Qumulo::Rest

  # === Description
  # An instance of request options is used to specify additional options that
  # can be passed to the HTTP layer when making a REST API call.
  #
  # It provides the following parameters:
  #
  # :client:: client object to use.
  # :http_timeout:: HTTP request timeout override
  # :not_authorized:: set true to skip adding authorization
  #
  class RequestOptions
    include Validator

    attr_reader :client           # client to use for the HTTP request
    attr_reader :http_timeout     # timeout value for HTTP request
    attr_reader :not_authorized   # whether to add Authorization header
    attr_reader :debug            # print debug information to stdout

    def initialize(hsh = {})
      @client = hsh[:client]
      validate_instance_of(":client", @client, ::Qumulo::Rest::Client) if @client
      @http_timeout = hsh[:http_timeout]
      @not_authorized = hsh[:not_authorized] ? true : false
      @debug = hsh[:debug] ? true : false
    end

  end
end

