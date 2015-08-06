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

require "fake_http"
require "qumulo/rest/exception"
module Qumulo::Rest

  module TestEnv

    # Utility for adding/checking test prefix string
    #
    INTEGRATION_TEST_PREFIX = "integration_test_"

    def with_test_prefix(name)
      INTEGRATION_TEST_PREFIX + name
    end

    def has_test_prefix?(name)
      unless name.is_a?(String)
        raise DataTypeError.new("Input [#{name.inspect}] is not a String!")
      end
      name =~ /^#{INTEGRATION_TEST_PREFIX}/
    end

    # Reading connection parameters from environment
    #
    def connection_params_from_env
      @username = ENV['QUMULO_USER'] || "admin"
      @password = ENV['QUMULO_PASS'] || "admin"
      @addr = ENV['QUMULO_ADDR'] || "localhost"
      @port = (ENV['QUMULO_PORT'] || 8000).to_i
    end

    # Setting up fake connection and login
    #
    def set_up_fake_connection
      FakeHttp.set_fake_response(:post, "/v1/login", {
        :code => 203,
        :attrs => {
          "key" => "fake-key",
          "key_id" => "fake-key-id",
          "algorithm" => "fake-algorithm",
          "bearer_token" => "1:fake-token"
        }})
      Client.configure(:addr => "fakeaddr", :port => 8000, :http_class => FakeHttp)
      Client.login(:username => "fakeuser", :password => "fakepass")
    end

    def tear_down_fake_connection
      Client.unconfigure
    end

  end

end
