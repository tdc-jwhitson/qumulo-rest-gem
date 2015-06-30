require "cgi"
require "date"
require "qumulo/rest/validator"
require "qumulo/rest/request_options"

# UTF8 = Iconv.new("UTF-8//IGNORE", "UTF-8")
module Qumulo::Rest

  # == Class Description
  # There is no such thing as "boolean" type in Ruby.  This class provides something
  # to put into "field" declaration in resource classes.
  class Boolean; end

  # == Class Description
  # Special data type specified for "query string parameter" key or value.
  # This data type only allows the following characters:
  #
  #   0-9, a-z, A-Z, or + - % . *
  #
  # This string is not URL encoded, and used as is. (so the caller must URL encode
  # any special characters that they want to pass as query string parameters)
  class QueryString < String
    class << self
      include Validator

      # === Description
      # Convert a query string parameter key (such as "page-size") to a valid Ruby
      # accessor method name (such as "page_size").
      #
      # === Parameters
      # name:: String to use for query string parameter key
      #
      def get_accessor_name(name)

        unless name.is_a?(String)
          raise ArgumentError.new(
            "Unexpected key: [#{name.inspect}] [required data type: String]")
        end

        unless name =~ /^[0-9a-zA-Z\-]+$/
          raise ArgumentError.new(
            "A query string parameter key cannot contain characters " +
            "other than 0-9, a-z, A-Z or -.")
        end

        name.gsub("-", "_")

      end

      # === Description
      # Convert Ruby value into a value that we can append to URI.
      #
      # === Parameters
      # val:: String, ruby value to send as part of query string
      #
      def payload_format(val)
        CGI.escape(validated_string("query string", val))
      end

      # === Description
      # Convert payload (a query string parameter component) to normal Ruby string.
      #
      # === Parameters
      # val:: String, CGI-escaped string to convert to noraml as Ruby string
      #
      def ruby_format(val)
        CGI.unescape(validated_string("query string", val))
      end

    end
  end

  # == Class Description
  # A special class used to describe an Array field with pre-determined type.
  # The @element_type indicates what elements the array field must have.
  #
  class TypedArray < Array
    NATIVE_FIELD_TYPES = [
      String,
      Integer,
      Bignum,
      DateTime,
      Boolean,
      Array,
      Hash
    ]

    class << self
      attr_reader :element_type
      def set_element_type(element_type)
        unless NATIVE_FIELD_TYPES.include?(element_type) or element_type < Base
          raise DataTypeError.new(
            "Unacceptable element_type #{element_type.inspect}; " +
            "it must be one of #{NATIVE_FIELD_TYPES.inspect} or " +
            "a type derived from Qumulo::Rest::Base")
        end
        @element_type = element_type
      end
    end
  end

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

      # Class accessors
      attr_reader :query_params_class
      attr_reader :result_class

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
      # instance variable set using .uri_spec method above. Note that you can't
      # define an attr_reader for this, since "uri_spec" is already a setter.
      #
      def get_uri_spec
        @uri_spec
      end

      # === Description
      # Returns a new class that inherits from TypedArray.  You can then set the
      # element type on it to indicate the element type.  This is useful when
      # defining a resource class that contains array fields that contain complex
      # objects in an array.  For example, you can declare NfsExport class as follows:
      #
      #    class NfsRestriction
      #      field :host_restrictions, array_of(String)
      #      field :read_only, Boolean
      #      field :user_mapping, String
      #      field :map_to_user_id, Bignum
      #    end
      #
      #    class NfsExport < Base
      #      field :id
      #      field :export_path
      #      field :fs_path
      #      field :restrictions, array_of(NfsRestriction)
      #    end
      #
      def array_of(type)
        new_class = Class.new(TypedArray)
        new_class.set_element_type(type)
        new_class
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
      # Bignum                    | String, like "10000000000000000000000000"
      # --------------------------+----------------------------------------------
      # Boolean                   | Boolean
      # --------------------------+----------------------------------------------
      # DateTime                  | String, like "2015-06-06T01:15:53.312045459Z"
      # --------------------------+----------------------------------------------
      # Class derived from Base   | Hash - what gets returned with .as_hash
      # --------------------------+----------------------------------------------
      # Hash (untyped)            | Hash, with arbitrary content
      # --------------------------+----------------------------------------------
      # Array (untyped)           | Array, with arbitrary content
      # --------------------------+----------------------------------------------
      # array_of(element_type)    | Array, with hash object that represents the
      #                           | given element type
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

        # XXX REFACTORING TASK
        # Instead of if/elif statements below, we should really define classes
        # that can take care of validation and value conversions.  See example of QueryString
        # below.  The interface should provide .ruby_format() and .payload_format() methods.

        # Define getter
        define_method(name) do

          # Query string parameter is special in that its value comes from @query, not @attrs
          if type == QueryString
            return QueryString.ruby_format(@query[opts[:key_name]])
          end

          # All other field values come out of @attrs and then gets translated
          json_val = @attrs[name_s]
          if [String, Integer, Boolean, Array, Hash].include?(type)
            json_val
          elsif type == Bignum
            json_val.to_i       # Ruby handles 64-bit integers seemlessly using Bignum
          elsif type == DateTime
            DateTime.parse(json_val)
          elsif type < TypedArray
            json_val.collect do |elt|
              entry = type.element_type.new
              entry.store_attrs(elt)
              entry
            end
          elsif type and type < Base     # if type is derived from Base
            type.new(json_val)
          else
            json_val
          end
        end

        # Define setter
        define_method(name_s + "=") do |val|

          # XXX REFACTORING TASK
          # This check should move into individual field type classes
          if not type.nil? and not val.is_a?(type)
            unless ((type == Bignum and val.is_a?(Fixnum)) or
                    (type == Boolean and val == true) or
                    (type == Boolean and val == false) or
                    (type == QueryString and val.is_a?(String)) or
                    (type < TypedArray and val.is_a?(Array)))
              raise DataTypeError.new(
                "Unexpected type: #{val.class.name} (#{val.inspect}) for #{name} " +
                "[required data type: #{type}]")
            end
          end

          if [nil, String, Integer, Boolean, Array, Hash].include?(type)
            @attrs[name_s] = val
          elsif type == Bignum
            @attrs[name_s] = val.to_s
          elsif type == DateTime
            @attrs[name_s] = val.strftime("%Y-%m-%dT%H:%M:%S.%NZ")
          elsif type < TypedArray
            @attrs[name_s] = val.collect do |elt|
              if elt.is_a?(type.element_type)
                elt.as_hash
              else
                raise DataTypeError.new(
                  "Unexected element #{elt.inspect} detected for #{name} array " +
                  "[required element type: #{type.element_type}]")
              end
            end
          elsif type and type < Base
            @attrs[name_s] = val.as_hash
          elsif type == QueryString
            @query[opts[:key_name]] = QueryString.payload_format(val)
          else
            raise DataTypeError.new(
              "Cannot store: #{val.inspect} into attribute: #{name} " +
              "[requires data type: #{type}]")
          end
        end
      end

      # === Description
      # Define query string parameters that are relevant for the given resource.
      #
      # === Parameters
      # key:: String, for the query string parameter key,
      #               e.g. like "allow-fs-path-create" or "page-size"
      #
      # === Notes
      # The value of a query string parameter is always a String.  The string
      # will be URL encoded before being sent in the HTTP request.
      #
      def query_param(key_name)

        # Turn the string into a valid Ruby accessor name: replace "-" with "_"
        accessor_name = QueryString.get_accessor_name(key_name)

        # Create a new class that represents query string parameters
        field accessor_name, QueryString, :key_name => key_name

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
        # When splitting path, preserve the trailing slash (hence, -1)
        path.split('/', -1).each do |part|
          resolved_part = (part =~ /^:/) ? CGI.escape(kv[part.sub(/^:/, '')].to_s) : part
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
      # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
      #                Or an instance of RequestOptions class.
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
      # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
      #                Or an instance of RequestOptions class.
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
      # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
      #                Or an instance of RequestOptions class.
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
      # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
      #                Or an instance of RequestOptions class.
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
    attr_reader :etag
    attr_reader :error
    attr_reader :code
    attr_reader :attrs
    attr_reader :body
    attr_reader :query

    # === Description
    # Take attributes and stores as instance variable.
    # Also initializes instance variables, as follows.
    #
    # === Instance Variables
    # @src_obj:: Hash object represents the up-to-date resource state
    #            -or- can be another Base-derived class instance to transfer content from
    # @error:: stores any error details returned by the server
    # @response:: last received Net::HTTPResponse object
    #
    def initialize(src_obj = {})
      if src_obj.is_a?(Hash)
        # convert symbol keys to string keys
        @query = {}
        @attrs = {}
        src_obj.each do |k, v|
          self.send(k.to_s + "=", v)
        end
        @body = ""
        @error = nil
        @response = nil
      else
        @query = src_obj.instance_variable_get("@query")
        @attrs = src_obj.instance_variable_get("@attrs")
        @body = src_obj.instance_variable_get("@body")
        @error = src_obj.instance_variable_get("@error")
        @response = src_obj.instance_variable_get("@response")
      end
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
    # Generate query string parameters string based on @query; The values and keys
    # are already URL encoded already, so no need to URL encode them again after this.
    #
    # === Returns
    # String, query string to attach to URL
    #
    def query_string_params
      str = @query.collect {|k, v| "#{k}=#{v}"}.join("&")
      str = "?" + str unless str.empty?
      str
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
    # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
    #                Or an instance of RequestOptions class.
    # === Returns
    # An instance of Qumulo::Rest::Http object
    # (or Qumulo::Rest::FakeHttp object for unit testing if client is a fake client)
    #
    def http(request_opts = {})
        if @@client_class.nil?
          raise ConfigError.new("Qumulo::Rest::Client class has not been loaded yet!")
        end
        if request_opts.is_a?(Hash)
          request_opts = RequestOptions.new(request_opts)
        else
          unless request_opts.is_a?(RequestOptions)
            raise ArgumentError.new("We need RequestOptions instance here")
          end
        end
        client = request_opts.client || @@client_class.default
        client.http(request_opts)
    end

    # === Description
    # Convert a path that may contain a variable (e.g. "/users/:id") to a fully
    # resolved path string (e.g. "/users/500"). This is an instance method,
    # and it invokes class method "resolve_path" to do this.
    #
    def resolved_path()
      self.class.resolve_path(self.class.get_uri_spec, @attrs) + query_string_params
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
    def store_result(result = {})
      @response = result[:response]
      @etag = @response ? @response["etag"] : nil
      @attrs = result[:attrs] if result[:attrs] # only update @attrs if success
      @error = result[:error]                   # clears @error if success
      @code = result[:code]
      if error?
        raise Qumulo::Rest::RequestFailed.new(
          "Request failed #{self.inspect}", @response)
      end
      if self.class.result_class
        self.class.result_class.new(self)
      else
        self
      end
    end

    # === Description
    # Directly set @attrs based on JSON payload.  This is used to store results
    # for nested secondary objects that are found in nested arrays.
    #
    # === Parameters
    # hsh:: Hash object directly decoded from JSON
    #
    def store_attrs(hsh = {})
      @attrs = hsh
    end

    # === Description
    # Perform POST request to create the resource on the server-side.
    #
    # === Parameters
    # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
    #                Or an instance of RequestOptions class.
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
    # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
    #                Or an instance of RequestOptions class.
    # === Returns
    # self
    #
    # === Raises
    # RequestFailed if error
    #
    def put(request_opts = {})
      store_result(http(request_opts).put(resolved_path, @attrs, @etag))
    end

    # === Description
    # Perform GET request to fetch the latest resource from the server-side.
    #
    # === Parameters
    # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
    #                Or an instance of RequestOptions class.
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
    # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
    #                Or an instance of RequestOptions class.
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
