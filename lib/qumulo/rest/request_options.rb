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

