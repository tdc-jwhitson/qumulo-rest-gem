#
#  Copyright 2015 Qumulo, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

require "cgi"
require "date"
require "qumulo/rest/validator"
require "qumulo/rest/request_options"

module Qumulo::Rest

  # === Module Description
  # Memoization helper.  This is used to maintain consistent reference to the REST
  # resource object that wraps a specific Hash or Array compoent in JSON payload.
  module Memoization

    # === Description
    # Check if the object has a memo
    def has_memo?(obj)
      obj.instance_variable_defined?("@qrest_memo")
    end

    # === Description
    # Get the memo from the given obj
    def get_memo(obj)
      obj.instance_variable_get("@qrest_memo")
    end

    # === Description
    # Add the memo to the given obj
    def set_memo(obj, memo)
      obj.instance_variable_set("@qrest_memo", memo)
    end

  end

  # ------------------------------------------------------------------------
  # Value converter classes
  #
  # A value converter class provides uniform interface used by the Base class to
  # convert between a native Ruby object and Qumulo API's JSON representation of
  # the Ruby object.  For example, Qumulo API represents any date time in a
  # ISO-8601 string that looks like the following:
  #
  #   "2015-06-06T01:15:53.312045459Z"
  #
  # This string is parsable into Ruby's native DateTime object.  The converter
  # class for DateTime will convert this string to native Ruby object.
  #
  # A converter class must provide the following class methods:
  # - is_acceptable?(allowed_type, ruby_obj)
  # - payload_format(ruby_obj)
  # - ruby_format(payload)
  #

  # === Class Description
  # This converter class returns identical value as converted value.  This is
  # appropriate for native types such as Integer, Fixed, String, Array, etc.
  class IdentityConverter
    class << self

      def is_acceptable?(allowed_type, ruby_obj) # :nodoc:
        allowed_type.nil? or ruby_obj.is_a?(allowed_type)
      end

      def payload_format(ruby_obj) # :nodoc:
        ruby_obj
      end

      def ruby_format(payload) # :nodoc:
        payload
      end

    end
  end

  # == Class Description
  # There is no such thing as "boolean" type in Ruby.  This class provides something
  # to put into "field" declaration in resource classes.
  class Boolean < IdentityConverter
    class << self
      def is_acceptable?(allowed_type, ruby_obj) # :nodoc:
        ruby_obj == true or ruby_obj == false
      end
    end
  end

  # === Class Description
  # This class converts between native Ruby DateTime object and Qumulo API's
  # JSON representation of a timestamp, which uses ISO-8601 form with fraction
  # component to represent nanoseconds.
  class DateTimeConverter < IdentityConverter
    class << self

      def ruby_format(val) # :nodoc:
        DateTime.parse(val)
      end

      def payload_format(ruby_obj) # :nodoc:
        ruby_obj.strftime("%Y-%m-%dT%H:%M:%S.%NZ")
      end

    end
  end

  # === Class Description
  # This class converts between native Ruby BigNum object and Qumulo API's
  # JSON representation of 64-bit integer, which is a string.
  class BignumConverter < IdentityConverter
    class << self

      def is_acceptable?(allowed_type, ruby_obj) # :nodoc:
        ruby_obj.is_a?(Integer) # any integer, even small, is acceptable
      end

      def ruby_format(val) # :nodoc:
        val.to_i
      end

      def payload_format(ruby_obj) # :nodoc:
        ruby_obj.to_s
      end

    end
  end

  # == Class Description
  # Special data type specified for "query string parameter" key or value.
  # This data type only allows the following characters:
  #
  #   0-9, a-z, A-Z, or + - % . *
  #
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

      def is_acceptable?(allowed_type, ruby_obj) # :nodoc:
        ruby_obj.is_a?(String)
      end

      def payload_format(val) # :nodoc:
        CGI.escape(validated_string("query string", val))
      end

      def ruby_format(val) # :nodoc:
        CGI.unescape(validated_string("query string", val))
      end

    end
  end

  # == Class Description
  # A special class used to describe an Array field with pre-determined type.
  # The @element_type indicates what elements the array field must have.
  #
  class TypedArray < IdentityConverter
    include Enumerable
    extend Forwardable

    attr_accessor :payload # JSON representation of the array
    def_delegator :@payload, :length
    def_delegator :@payload, :delete_at

    # === Description
    # Create an instance of a typed array.
    def initialize(input = [])
      case input
      when TypedArray
        @payload = input.payload # Unwrap and store payload
      when Array
        @payload = input.collect do |elt|
          # Test if individual element is already in element_type.  If so, we
          # need to store them in payload format
          if elt.is_a?(self.class.element_type)
            to_payload(elt)
          elsif elt.is_a?(Hash)
            elt # Assume that elt is coming from payload already
          else
            raise DataTypeError.new(
              "Unexected element #{elt.inspect} detected " +
              "[required element type: #{self.class.element_type}]")
          end
        end
      else
        raise DataTypeError.new("Only TypedArray or Array is valid here")
      end
    end

    # === Description
    # Convert the given Ruby object of associated element_type to JSON representation
    # Memoize the original ruby_elt in the payload so that we can return the same ruby object.
    def to_payload(ruby_elt)
      type = self.class.element_type
      converter = CONVERTER_CLASS[type] || type
      converter.payload_format(ruby_elt)
    end

    # === Description
    # Convert the given JSON payload to Ruby object of associated element_type specified at class level
    # Memoize the original ruby_elt in the payload so that we can return the same ruby object.
    def to_ruby_obj(payload_elt)
      type = self.class.element_type
      converter = CONVERTER_CLASS[type] || type
      converter.ruby_format(payload_elt)
    end

    # Intercept a small subset of Array operations and perform convertions as
    # the caller accesses array elements.
    #
    # XXX - Many array operations are not supported for now, including: &, *, +, -,
    #       <=>, ==, ===, =~. at, delete, etc.  To support these properly, we will
    #       need to extend Base class further.

    def ==(other) # :nodoc:
      @payload == other.payload
    end

    # === Description
    # Override each to return an element converted from the JSON payload to proper
    # Ruby object as specified by element_type.  The included Enumerable mix-in will
    # take care of many Ruby functions that rely on .each method.
    def each(&blk)
      @payload.each do |elt|
        blk.call(to_ruby_obj(elt))
      end
      self
    end

    def [](i)
      to_ruby_obj(@payload[i])
    end

    def last()
      self[-1]
    end

    def []=(i, ruby_obj)
      @payload[i] = to_payload(ruby_obj)
      ruby_obj
    end

    def <<(ruby_obj)
      @payload << to_payload(ruby_obj)
      self
    end

    def insert(index, ruby_obj)
      @payload.insert(index, to_payload(ruby_obj))
    end

    def delete_if(&blk)
      @payload.delete_if do |elt|
        blk.call(to_ruby_obj(elt))
      end
      self
    end

    # TypedArray class set-up, and converter functions
    class << self
      include Memoization

      NATIVE_FIELD_TYPES = [String, Integer, Bignum, Float, DateTime, Boolean, Array, Hash]
      attr_reader :element_type

      def set_element_type(element_type) # :nodoc:
        # For now, TypedArray of TypedArray is not supported.  No reason.
        # Just don't see use case, and didn't write test for it.
        unless NATIVE_FIELD_TYPES.include?(element_type) or element_type < Base
          raise DataTypeError.new(
            "Unacceptable element_type #{element_type.inspect}; " +
            "it must be one of #{NATIVE_FIELD_TYPES.inspect} or " +
            "a type derived from Qumulo::Rest::Base")
        end
        @element_type = element_type
      end

      def is_acceptable?(allowed_type, ruby_obj) # :nodoc:
        ruby_obj.is_a?(Array) or ruby_obj.is_a?(TypedArray)
      end

      def ruby_format(payload) # :nodoc:
        if payload.is_a?(Array)
          unless has_memo?(payload)
            # We are converting payload from server, so simply set the payload
            obj = self.new
            obj.payload = payload
            set_memo(payload, obj)
          end
          get_memo(payload)
        else
          raise DataTypeError.new("Array expected, but got #{payload.inspect}")
        end
      end

      def payload_format(ruby_obj) # :nodoc:
        case ruby_obj
        when TypedArray
          ruby_obj.payload
        when Array
          # Caller must be assigning a Ruby array to replace this section of the payload.
          # Produce the new payload fragment to replace the existing array payload.
          ruby_obj.collect do |elt|
            unless elt.is_a?(element_type)
              raise DataTypeError.new(
                "Unexected element #{elt.inspect} detected " +
                "[required element type: #{element_type}]")
            end
            converter = CONVERTER_CLASS[element_type] || element_type
            converter.payload_format(elt)
          end
        else
          raise DataTypeError.new("Only TypedArray or Array is valid here")
        end
      end
    end

  end

  # The following table provides the converter classes that correspond to each
  # Ruby object class allowed by the Base class for REST resources.
  # key = Ruby class, value = converter class
  CONVERTER_CLASS = {
    nil         => IdentityConverter,
    String      => IdentityConverter,
    Integer     => IdentityConverter,
    Float       => IdentityConverter,
    Array       => IdentityConverter,
    Hash        => IdentityConverter,
    Bignum      => BignumConverter,
    DateTime    => DateTimeConverter,
    Boolean     => Boolean,
    TypedArray  => TypedArray,
    QueryString => QueryString
  }

  # == Class Description
  # All other RESTful resource classes inherit from this class.
  # This class takes care of the following:
  # * DSL for defining RESTful resource
  # * HTTP request/response handling
  # * Response Parsing
  #
  class Base < IdentityConverter
    # Set by client class once it gets loaded
    @@client_class = nil

    # --------------------------------------------------------------------------
    # Class methods
    #
    class << self
      include Qumulo::Rest::Validator
      include Memoization

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
      # Returns a new class that inherits from TypedArray.  Then, the given type
      # is set as the allowed element type.  This is useful when defining a resource
      # class that contains array fields that contain complex objects in an array.
      #
      # For example, you can declare NfsExport class as follows:
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
      # Integer (Fixnum)          | Number (integer form)
      # --------------------------+----------------------------------------------
      # Bignum                    | String, like "10000000000000000000000000"
      # --------------------------+----------------------------------------------
      # Float                     | Number (floating-point format)
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

        # Define getter - using a converter class, turn payload value into a ruby object to return
        define_method(name) do
          converter = CONVERTER_CLASS[type] || type
          val = (converter == QueryString) ? @query[opts[:key_name]] : @attrs[name_s]
          converter.ruby_format(val)
        end

        # Define setter - using a converter class, turn ruby object into json payload to store
        define_method(name_s + "=") do |ruby_obj|
          converter = CONVERTER_CLASS[type] || type
          unless converter.respond_to?(:is_acceptable?)
             raise DataTypeError.new("Type #{converter} is not a proper converter.")
          end
          unless converter.is_acceptable?(type, ruby_obj)
             raise DataTypeError.new(
               "Unexpected type: #{ruby_obj.class.name} (#{ruby_obj.inspect}) for #{name} " +
               "[required data type: #{type}]")
          end
          if converter == QueryString
            @query[opts[:key_name]] = converter.payload_format(ruby_obj)
          else
            @attrs[name_s] = converter.payload_format(ruby_obj)
          end
        end
      end

      def ruby_format(payload) # :nodoc:
        if payload.is_a?(Hash)
          unless has_memo?(payload)
            # We are converting payload from server, so simply set the attrs
            obj = self.new
            obj.attrs = payload
            set_memo(payload, obj)
          end
          get_memo(payload)
        else
          raise DataTypeError.new("Hash expected, but got #{payload.inspect}")
        end
      end

      def payload_format(ruby_obj) # :nodoc:
        ruby_obj.as_hash
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
      # For example, you might have a REST API that returns the employee of the month.
      # Though we could have the API entry point EmployeeOfMonth resource, but it may
      # be simpler to have this API return just an Employee resource, which may already
      # be defined. In this case, you might define employee of the month REST resource
      # as follows:
      #
      #   class Employee < Qumulo::Rest::Base
      #     uri_spec "/employees/:id"
      #     field :id, String
      #     field :hourly_rate, Float
      #   end
      #
      #   class EmployeeOfMonth < Qumulo::Rest::Base
      #     uri_spec "/employee-of-month"
      #     result Employee
      #   end
      #
      # And use EmployeeOfMonth as follows:
      #
      #   employee = EmployeeOfMonth.get
      #   employee.hourly_rate += 1.00
      #   employee.put
      #
      # === Parameters
      # cls:: a class object that derives from Qumulo::Rest::Base.
      #
      def result(cls)
        if cls < Base
          @result_class = cls
        else
          raise DataTypeError.new("#{cls.inspect} must be derived from Qumulo::Rest::Base.")
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
            raise UriError.new("Cannot resolve #{part} in path #{path} from #{kv.inspect}")
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
    # Base object functionality
    # XXX - need to add more comparators

    def ==(other) # :nodoc:
      @attrs == other.attrs
    end

    # --------------------------------------------------------------------------
    # CRUD operations using instance
    #

    # last received response; if nil, HTTP request was never sent from instance
    attr_accessor :response
    attr_reader :etag
    attr_reader :error
    attr_reader :code
    attr_accessor :attrs # JSON representation of the object
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
        # This is mainly used to convert a response into a different result_class,
        # so we are not bothering to clone the contents of the src_obj.
        @response = src_obj.response
        @error = src_obj.error
        @attrs = src_obj.code
        @attrs = src_obj.attrs
        @body = src_obj.body
        @query = src_obj.query
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
