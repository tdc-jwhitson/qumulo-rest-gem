require "qumulo/rest/exception"
require "qumulo/rest/validator"

module Qumulo::Rest

  # === Description
  # This class acts as a test double for Qumulo::Rest::Http class (the real thing)
  # during unit tests.
  #
  class FakeHttp
    @@fake_responses = {}

    class << self
      include Validator

      # === Description
      # Set fake response corresponding to the path for the given method
      #
      # === Parameters
      # method:: symbol one of :post, :put, :get, or :delete
      # path:: URI, including the query string parameters
      # hsh:: response to return, in the form of:
      #
      #   For success:
      #   {
      #     :code => <Integer representation of status code>,
      #     :attrs => <Hash object representing resource attributes>
      #   }
      #
      #   For errors:
      #   {
      #     :code => <Integer representation of status code>,
      #     :error => <Hash object representing error structure>
      #   }
      #
      # === Raises
      # TestError if you have bad things in your arguments
      #
      def set_fake_response(method, path, hsh)
        validated_method_sym(:method, method)
        validated_non_empty_string(:path, path)
        if not hsh[:code]
          raise TestError.new("You must provide :code value in hsh")
        end
        if hsh[:attrs] and hsh[:error]
          raise TestError.new("You can't set both :attrs and :error in hsh")
        end
        if not hsh[:attrs].is_a?(Hash) and not hsh[:error].is_a?(Hash)
          raise TestError.new("You must set either :attrs or :error in hsh")
        end
        @@fake_responses[method] ||= {}
        @@fake_responses[method][path] = hsh # overrides existing entry
      end
    end

    # --------------------------------------------------------------------------
    # HTTP instance methods
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
      @host = host
      @port = port
      @open_timeout = timeout
      @read_timeout = timeout
      @bearer_token = bearer_token
    end

    # === Description
    # Get fake response corresponding to path for the given method
    #
    # === Parameters
    # method:: symbol one of :post, :put, :get, or :delete
    # path:: URI, including the query string parameters
    #
    # === Returns
    # Corresponding response Hash object
    #
    def get_fake_response(method, path)
      @@fake_responses[method][path]
    end

    # === Description
    # Return fake response matching the path to POST request
    #
    # === Parameters
    # path:: URI path, including query string parameters
    # attrs:: Hash object containing key-value pairs representing resource
    #
    # === Returns
    # result Hash object from @@fake_responses hash
    #
    def post(path, attrs)
      return get_fake_response(:post, path)
    end

    # === Description
    # Return fake response matching the path to PUT request
    #
    # === Parameters
    # path:: URI path, including query string parameters
    # attrs:: Hash object containing key-value pairs representing resource
    #
    # === Returns
    # result Hash object from @@fake_response hash
    #
    def put(path, attrs)
      return get_fake_response(:put, path)
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
      return get_fake_response(:get, path)
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
      return get_fake_response(:delete, path)
    end

  end
end
