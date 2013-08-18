require "qumulo/rest/exception"
require "qumulo/rest/login"
module Qumulo::Rest

  # == Class Description
  # This class represents a qumulo client. This client keeps track of connection
  # information, and handles authentication during all API calls. Here is
  # typical example usage:
  #
  # Qumulo::Rest::Clinet.configure(:host => "192.168.1.100", :port => 8000)
  # Qumulo::Rest::Client.login(:username => "admin", :password => "admin")
  #
  # After the above two lines of code, you can create, fetch, update, and delete
  # RESTful resources using classes found in "qumulo/rest/*.rb"
  #
  class Client

    # === Description
    # Configure connection information for RESFful API.
    # This class method returns a new client object you can use.
    # Also, the first new client will be set as the default client within the
    # current process. You can replace the default client if you pass in
    # :set_default => true option.
    #
    # === Parameters
    # opts:: Hash object containing connection information
    # opts[:host]:: DNS name or IP address
    # opts[:port]:: Integer port value
    # opts[:use_as_default]:: true to replace existing default client
    # false to not set default client.
    #
    # === Returns
    # A client object (instance of Qumulo::Rest::Client).
    # Note that you do not need to keep track of your client object
    # if you are only going to talk to 1 cluster. You only need to
    # keep track of multiple client objects if you want to talk to
    # 2 or more clusters within the same process. This method is basically
    # used to create and sets the default client in most cases.
    #
    def self.configure(opts)
      client = self.new(opts[:host], opts[:port])
      if opts.key?(:use_as_default) and opts[:use_as_default]
        @default_client = client
      elsif not opts.key?(:use_as_default)
        @default_client ||= client
      end
      client
    end

    # === Description
    # Return the default client object
    #
    # === Returns
    # An instance of Qumulo::Rest::Client
    #
    def self.default
      @default_client
    end

    # === Description
    # Log into Qumulo storage appliance.
    #
    # === Parameters
    # args:: Hash object containing :username and :password keys
    #
    # === Throws
    # Qumulo::Rest::AuthenticationError
    #
    def self.login(args)
      @default_client.login(args)
    end

    # --------------------------------------------------------------------------
    # Constructor
    #

    attr_reader :host
    attr_reader :port

    # === Description
    # Constructor for Qumulo::Client
    #
    # === Parameters
    # host:: DNS name or IP address
    # port:: Integer port value
    #
    def initialize(host, port)
      unless host.is_a?(String)
        throw Error::ArgumentError.new("host is not string: #{host.inspect}")
      end
      unless port.is_a?(Integer)
        throw Error::ArgumentError.new("port is not integer: #{port.inspect}") 
      end
      @host = host
      @port = port
    end

    # === Description
    # Log into Qumulo storage appliance.
    #
    # === Parameters
    # args:: Hash object containing :username and :password keys
    #
    # === Throws
    # Qumulo::Rest::ArgumentError
    # Qumulo::Rest::AuthenticationError
    #
    def login(args)
      @login = Login.new(args)
      @login.execute
    end

  end
end
