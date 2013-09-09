require "qumulo/rest/validator"
require "qumulo/rest/http"
require "qumulo/rest/client"

UTF8 = Iconv.new("UTF-8//IGNORE", "UTF-8")
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
    # Class methods
    #
    class << self
      include Qumulo::Rest::Validator

      # ------------------------------------------------------------------------
      # Resource DSL
      #

      # === Description
      # Indicates the format of URL path to locate a resource.
      #
      #   uri_spec "/conf/network"  # singleton resource for network config
      #   uri_spec "/users/:id"     # user resource located by :id
      #
      # Note that if we can locate a single resource by "/users/:id",
      # it is assumed that we can get all users by "/users/".
      #
      def uri_spec(uri_spec)
        # @uri_spec is not a class instance variable of the Base class.
        # It is a class instance variable of the drived class.
        @uri_spec = uri_spec
      end

      # === Description
      # This method can be used against a drived class to get the @uri_spec
      # instance variable set using .path method above.
      #
      def get_uri_spec
        @uri_spec
      end

      # === Description
      # Define accessors for a JSON attribute. This looks for the named attribute
      # in @attrs. You can optionally define type of the attribute, which gets used
      # inside the setter if provided. You can also specify additional options.
      # Here are some examples:
      #
      #   field key         # It's OK to not specify data type; this is Ruby!
      #   field id, String  # Adding type will validate things for you though
      #
      # === Parameters
      # name:: Name of the attribute as Symbol
      # type:: Class of the attribute data
      # opts:: Hash object representing any additional options
      #
      def field(name, type = nil, opts = {})
        define_method(name) do
          @attrs[name.to_s]
        end
        define_method(name.to_s + "=") do |val|
          if type and not val.is_a?(type)
            raise TypeError.new("Unexpected type: #{val.inspect} for #{name}")
          end
          @attrs[name.to_s] = val
        end
      end

      # --------------------------------------------------------------------------
      # CRUD using class methods
      #

      # === Description
      # Convert a path that may contain a variable (e.g. "/users/:id") to a fully
      # resolved path string (e.g. "/users/500").
      #
      # === Parameters
      # path:: a path string to resolve, e.g. "/users/:id"; if missing, defaults
      #        to the default path of the current class.
      # kv:: key-value hash, to be used to populate variable parts of uri spec;
      #      keys must be Strings, not Symbols
      #
      # === Returns
      # A path String with all the variable parts resolved.
      #
      def resolve_path(path, kv)
        validate_instance_of(:kv, kv, Hash)
        resolved = []
        path.split('/').each do |part|
          resolved_part = (part =~ /^:/) ? kv[part.sub(/^:/, '')].to_s : part
          if (part != "" and resolved_part == "")
            throw UrlError.new("Cannot resolve #{part} in path #{path} from #{kv.inspect}")
          end
          resolved << resolved_part
        end
        resolved.join('/')
      end

      # === Description
      # Perform POST request to create the resource on the server-side.
      #
      # === Parameters
      # attrs:: attributes to pass to post
      # request_opts:: Hash object to control request details; see http_execute
      # request_opts[:client]:: (optional) client object to use.
      # request_opts[:http_timeout]:: (optional) HTTP request timeout override
      # request_opts[:not_authorized]:: set true to skip adding authorization
      #
      # === Returns
      # Returns an instance object of relevant resource class representing
      # the new resource
      #
      # === Raises
      # RequestFailed if error
      #
      def post(attrs = {}, request_opts = {})
        self.new(attrs).post(request_opts)
      end

      # === Description
      # Perform PUT request to update the resource on the server-side.
      #
      # === Parameters
      # attrs:: attributes to pass to put
      # request_opts:: Hash object to control request details; see http_execute
      # request_opts[:client]:: (optional) client object to use.
      # request_opts[:http_timeout]:: (optional) HTTP request timeout override
      # request_opts[:not_authorized]:: set true to skip adding authorization
      #
      # === Returns
      # Returns an instance object.
      #
      # === Raises
      # RequestFailed if error
      #
      def put(attrs = {}, request_opts = {})
        self.new(attrs).put(request_opts)
      end

      # === Description
      # Retrieve an object from the server.
      #
      # === Parameters
      # attrs:: attributes of the resource to get.  Mostly :id is interesting in case of get.
      # request_opts:: Hash object to control request details; see http_execute
      # request_opts[:client]:: (optional) client object to use.
      # request_opts[:http_timeout]:: (optional) HTTP request timeout override
      # request_opts[:not_authorized]:: set true to skip adding authorization
      #
      # === Returns
      # Instance of the resource
      #
      # === Raises
      # RequestFailed if error
      #
      def get(attrs = {}, request_opts = {})
        self.new(attrs).get(request_opts)
      end

      # === Description
      # Delete the current resource from the server. This method ignores errors.
      #
      # === Parameters
      # attrs:: attributes of the resource to delete.  Mostly :id is interesting in case of delete.
      # request_opts:: Hash object to control request details; see http_execute
      # request_opts[:client]:: (optional) client object to use.
      # request_opts[:http_timeout]:: (optional) HTTP request timeout override
      # request_opts[:not_authorized]:: set true to skip adding authorization
      #
      # === Returns
      # Instance of the resource
      #
      # === Raises
      # RequestFailed if error
      #
      def delete(attrs = {}, request_opts = {})
        self.new(attrs).delete(request_opts)
      end

    end

    # --------------------------------------------------------------------------
    # CRUD operations using instance
    #

    # last received response; if nil, HTTP request was never sent from instance
    attr_accessor :response

    attr_reader :error
    attr_reader :code
    attr_reader :attrs
    attr_reader :body

    # === Description
    # Take attributes and stores as instance variable.
    # Also initializes instance variables, as follows.
    #
    # === Instance Variables
    # @attrs:: Hash object represents the up-to-date resource state
    # @error:: stores any error details returned by the server
    # @response:: last received Net::HTTPResponse object
    #
    def initialize(attrs)
      # convert symbol keys to string keys
      @attrs = {}
      attrs.each do |k, v|
        @attrs[k.to_s] = v
      end
      @body = ""
      @error = nil
      @response = nil
    end

    # === Description
    # Check if the last HTTP request has failed.
    #
    # === Returns
    # true if request has failed,
    # false if request was success or this is a new instance
    #
    def error?
      not @error.nil?
    end

    # === Description
    # Create an http request to call HTTP verbs on.  This facilitates injecting
    # fake http object during unit test.
    #
    # === Parameters
    # request_opts:: Hash object to control request details; see http_execute
    # request_opts[:client]:: (optional) client object to use.
    # request_opts[:http_timeout]:: (optional) HTTP request timeout override
    # request_opts[:not_authorized]:: set true to skip adding authorization
    #
    # === Returns
    # An instance of Qumulo::Rest::Http object
    # (or Qumulo::Rest::FakeHttp object for unit testing if client is a fake client)
    #
    def http(request_opts = {})
        client = request_opts[:client] || Qumulo::Rest::Client.default
        client.http(request_opts)
    end

    # === Description
    # Convert a path that may contain a variable (e.g. "/users/:id") to a fully
    # resolved path string (e.g. "/users/500"). This is an instance method,
    # and it invokes class method "resolve_path" to do this.
    #
    def resolved_path()
      self.class.resolve_path(self.class.get_uri_spec, @attrs)
    end

    # === Description
    # Process the result of an HTTP request.
    # If http request is successful, response object is stored in @response,
    # @error is cleared, and the response body is parsed to populate @attrs.
    # If http request fails, @response and @error are populated.
    #
    # === Parameters
    #  {
    #    :response => <Net::HTTPResponse object resulting from Http request>,
    #    :attrs => <Hash object for resource attrs> or <nil> if request failed,
    #    :error => <Hash object for error structure> or <nil> if request success
    #  }
    #
    # === Returns
    # self
    #
    def store_result(result)
      @response = result[:response]
      @attrs = result[:attrs] if result[:attrs] # only update @attrs if success
      @error = result[:error]                   # clears @error if success
      @code = result[:code]
      if error?
        raise Qumulo::Rest::RequestFailed.new(
          "Request failed #{self.inspect}", @response)
      end
      self
    end

    # === Description
    # Perform POST request to create the resource on the server-side.
    #
    # === Parameters
    # request_opts[:client]:: (optional) client object to use.
    # request_opts[:http_timeout]:: (optional) HTTP request timeout override
    # request_opts[:not_authorized]:: set true to skip adding authorization
    #
    # === Returns
    # self
    #
    # === Raises
    # RequestFailed if error
    #
    def post(request_opts = {})
      store_result(http(request_opts).post(resolved_path, @attrs))
    end

    # === Description
    # Perform PUT request to update the resource on the server-side.
    #
    # === Parameters
    # attrs:: attributes to pass to post
    # request_opts:: Hash object to control request details
    # request_opts[:client]:: (optional) client object to use.
    # request_opts[:http_timeout]:: (optional) HTTP request timeout override
    # request_opts[:not_authorized]:: set true to skip adding authorization
    #
    # === Returns
    # self
    #
    # === Raises
    # RequestFailed if error
    #
    def put(request_opts = {})
      store_result(http(request_opts).put(resolved_path, @attrs))
    end

    # === Description
    # Perform GET request to fetch the latest resource from the server-side.
    #
    # === Parameters
    # request_opts:: Hash object to control request details; see http_execute
    # request_opts[:client]:: (optional) client object to use.
    # request_opts[:http_timeout]:: (optional) HTTP request timeout override
    # request_opts[:not_authorized]:: set true to skip adding authorization
    #
    # === Returns
    # self
    #
    # === Raises
    # RequestFailed if error
    #
    def get(request_opts = {})
      store_result(http(request_opts).get(resolved_path))
    end

    # === Description
    # Delete the current resource from the server.
    #
    # === Parameters
    # request_opts:: Hash object to control request details; see http_execute
    # request_opts[:client]:: (optional) client object to use.
    # request_opts[:http_timeout]:: (optional) HTTP request timeout override
    # request_opts[:not_authorized]:: set true to skip adding authorization
    #
    # === Returns
    # self
    #
    # === Raises
    # RequestFailed if error
    #
    def delete(request_opts = {})
      store_result(http(request_opts).delete(resolved_path))
    end

  end
end
