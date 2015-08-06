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

require "qumulo/rest/exception"
require "qumulo/rest/request_options"
require "qumulo/rest/validator"
require "qumulo/rest/http"
require "qumulo/rest/base"
require "qumulo/rest/v1/login_session"
module Qumulo::Rest

  # == Class Description
  # This class represents a qumulo client. This client keeps track of connection
  # information, and handles authentication during all API calls. Here is
  # typical example usage:
  #
  #   Qumulo::Rest::Clinet.configure(:addr => "192.168.1.100", :port => 8000)
  #   Qumulo::Rest::Client.login(:username => "admin", :password => "admin")
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
    # client_opts:: Hash object containing connection information
    # client_opts[:addr]:: DNS name or IP address
    # client_opts[:port]:: Integer port value
    # client_opts[:http_timeout]:: default HTTP request timeout
    # client_opts[:http_class]:: set a different HTTP library than Qumulo::Rest::Http
    #
    # === Returns
    # A client object (instance of Qumulo::Rest::Client).
    # Note that you do not need to keep track of your client object
    # if you are only going to talk to 1 cluster.
    #
    # === Raises
    # ConfigError - if client has been configured already
    #               or if invalid configuration options are given.
    #
    def self.configure(client_opts)
      raise ConfigError.new("Client already configured; " +
        "use Client.unconfigure to change configuration") if @default_client
      @default_client = self.new(client_opts)
      @default_client
    end

    # === Description
    # Clear the default client; this is mainly used for testing or for security
    #
    def self.unconfigure
      @default_client = nil
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
    # === Raises
    # Qumulo::Rest::AuthenticationError
    #
    def self.login(args)
      unless @default_client
        raise ConfigError.new("Cannot login without configuring client")
      end
      @default_client.login(args)
    end

    # === Description
    # Clear login session.
    #
    def self.logout
      unless @default_client
        raise ConfigError.new("Cannot log out without configuring client")
      end
      @default_client.logout
    end

    # --------------------------------------------------------------------------
    # Constructor
    #
    include Validator

    attr_reader :addr
    attr_reader :port
    attr_reader :http_timeout
    attr_reader :http_class

    # === Description
    # Constructor for Qumulo::Client
    #
    # === Parameters
    # client_opts:: Hash object containing connection information
    # client_opts[:addr]:: DNS name or IP address
    # client_opts[:port]:: Integer port value [default: 8000]
    # client_opts[:http_timeout]:: default HTTP request timeout
    # client_opts[:http_class]:: set a different HTTP library than Qumulo::Rest::Http
    #
    def initialize(client_opts)
      @addr = validated_non_empty_string(":addr", client_opts[:addr])
      @port = validated_positive_int(":port", client_opts[:port] || 8000)
      @http_timeout = validated_positive_int(":http_timeout", client_opts[:http_timeout] || 30)
      @http_class = client_opts[:http_class] || Http
    end

    # === Description
    # Return HTTP request object connected to the client.
    #
    # === Parameters
    # request_opts:: an instance of RequestOptions class.
    #
    # === Returns
    # An instance of Qumulo::Rest::Http object (or a FakeHttp obect if @http_class is set)
    #
    # === Raises
    # LoginRequired unless a valid login session has been established
    #
    def http(request_opts = nil)
      request_opts ||= RequestOptions.new
      timeout = request_opts.http_timeout || @http_timeout
      bearer_token = request_opts.not_authorized ? nil : get_bearer_token
      @http_class.new(@addr, @port, timeout, bearer_token, request_opts)
    end

    # === Description
    # Clear login_session
    #
    def logout
      @login_session = nil
    end

    # === Description
    # Log into Qumulo storage appliance.
    #
    # === Parameters
    # args:: Hash object containing :username and :password keys;
    # e.g. {:username => "admin", :password => "admin"}
    #
    # === Raises
    # Qumulo::Rest::ValidationError
    # Qumulo::Rest::AuthenticationError
    #
    def login(args)
      session = V1::LoginSession.new(args)
      session.start # may raise exceptions here
      @login_session = session
    end

    # === Description
    # Returns login session that can provide key and key_id
    #
    # === Raises
    # LoginRequired unless a valid login session has been established
    #
    def get_login_session
      raise LoginRequired.new("Login required", self) unless @login_session
      @login_session
    end

    # === Description
    # Returns a bearer token that can be added to "Authorization" header of a request.
    #
    # === Raises
    # LoginRequired unless a valid login session has been established
    #
    def get_bearer_token
      "Bearer " + get_login_session.bearer_token.to_s
    end

  end

  # Need to do this here to break the dependency cycle:
  # Client ---> LoginSession ---> Base --(X)-> Client
  Qumulo::Rest::Base.set_client_class(Client)
end
