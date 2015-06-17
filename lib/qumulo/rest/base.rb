require "date"
require "qumulo/rest/validator"

# UTF8 = Iconv.new("UTF-8//IGNORE", "UTF-8")
module Qumulo::Rest

  # == Class Description
  # All other RESTful resource classes inherit from this class.
  # This class takes care of the following:
  # * DSL for defining RESTful resource
  # * HTTP request/response handling
  # * Response Parsing
  #
  class Base
    # Set by client class once it gets loaded
    @@client_class = nil

    # --------------------------------------------------------------------------
    # Class methods
    #
    class << self
      include Qumulo::Rest::Validator

      # === Description
      # Set the client class once the client class gets loaded.
      # Before then, this Base class cannot make REST API calls (which sort of makes sense).
      #
      # === Paramters
      # cls:: a class object, most likely Qumulo::Rest::Client
      #
      def set_client_class(cls)
        @@client_class = cls
      end

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
      #
      # Here are some examples:
      #
      #   field key          # It's OK to not specify data type; this is Ruby!
      #   field id, String   # Adding type will validate things for you though
      #
      # Specifying types help you convert between Qumulo API's JSON representation
      # of the type, and a convenient Ruby type.  Here are all supported types to
      # use with the field directive:
      #
      # Type specified            | How it is stored in Qumulo API JSON
      # --------------------------+----------------------------------------------
      # String                    | String (unicode)
      # --------------------------+----------------------------------------------
      # Integer (Fixnum)          | Integer
      # --------------------------+----------------------------------------------
      # DateTime                  | String, like "2015-06-06T01:15:53.312045459Z"
      # --------------------------+----------------------------------------------
      # Bignum                    | String, like "10000000000000000000000000"
      # --------------------------+----------------------------------------------
      # Class derived from Base   | Hash - what gets returned with .as_hash
      # --------------------------+----------------------------------------------
      # Hash (untyped)            | Hash, with arbitrary content
      # --------------------------+----------------------------------------------
      # Array (untyped)           | Array, with arbitrary content
      # --------------------------+----------------------------------------------
      #
      # Note that you can use Hash or Array to use a fragment of JSON dictionary
      # without any conversion or validation.  This is a good way to deal with a
      # lot of data (e.g. in case of analytics data) efficiently.
      #
      # === Parameters
      # name:: Name of the attribute as Symbol
      # type:: Class of the attribute data
      # opts:: Hash object representing any additional options
      #
      def field(name, type = nil, opts = {})

        name_s = name.to_s

        # Define getter
        define_method(name) do
          json_val = @attrs[name_s]
          if [String, Integer, Array, Hash].include?(type)
            json_val
          elsif type == Bignum
            json_val.to_i       # Ruby handles 64-bit integers seemlessly using Bignum
          elsif type == DateTime
            DateTime.parse(json_val)
          elsif type and type < Base     # if type is derived from Base
            type.new(json_val)
          else
            json_val
          end
        end

        # Define setter
        define_method(name_s + "=") do |val|

          if not type.nil? and not val.is_a?(type)
            unless type == Bignum and val.is_a?(Fixnum)
              raise DataTypeError.new(
                "Unexpected type: #{val.class.name} (#{val.inspect}) for #{name}")
            end
          end

          if [nil, String, Integer, Array, Hash].include?(type)
            @attrs[name_s] = val
          elsif type == Bignum
            @attrs[name_s] = val.to_s
          elsif type == DateTime
            @attrs[name_s] = val.strftime("%Y-%m-%dT%H:%M:%S.%NZ")
          elsif type and type < Base
            @attrs[name_s] = val.as_hash
          else
            raise DataTypeError.new(
              "Cannot store: #{val.inspect} into attribute: #{name} " +
              "[requires: #{type}]")
          end
        end
      end

      # === Description
      # Set the result class.  When result_class is set, the result class gets
      # returned, instead of the original class.
      #
      # === Parameters
      # cls:: a class object that derives from Qumulo::Rest::Base.
      #
      def result(cls)
        if cls < Base
          @result_class = cls
        else
          raise DataTypeError.new("#{cls.inspect} is not derived from Qumulo::Rest::Base.")
        end
      end

      # === Description
      # Return the result class closest to the current derived class.
      #
      def result_class
        @result_class
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
        path.split('/', -1).each do |part|
          resolved_part = (part =~ /^:/) ? kv[part.sub(/^:/, '')].to_s : part
          if (part != "" and resolved_part == "")
            throw UriError.new("Cannot resolve #{part} in path #{path} from #{kv.inspect}")
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
    def initialize(attrs = {})
      # convert symbol keys to string keys
      @attrs = {}
      attrs.each do |k, v|
        self.send(k.to_s + "=", v)
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
    # Return the object as Hash.  This is simply returns @attrs, since we always
    # maintain the JSON-ifiable hash in @attrs via accessors.
    #
    def as_hash
      @attrs
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
        if @@client_class.nil?
          raise ConfigError.new("Qumulo::Rest::Client class has not been loaded yet!")
        end
        client = request_opts[:client] || @@client_class.default
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
    # result:: Hash object of form:
    # {
    #   :response => <Net::HTTPResponse object resulting from Http request>,
    #   :code => integer HTTP status code,
    #   :attrs => <Hash object for resource attrs> or <nil> if request failed,
    #   :error => <Hash object for error structure> or <nil> if request success
    # }
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
      if self.class.result_class
        self.class.result_class.new(@attrs)
      else
        self
      end
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
