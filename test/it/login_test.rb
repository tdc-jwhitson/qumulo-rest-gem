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

require 'minitest/autorun'
require 'test_env'
require 'qumulo/rest'

module Qumulo::Rest
  class LoginTest < Minitest::Test
    include TestEnv

    def setup
      connection_params_from_env # sets @username, @password, @addr, @port
      Client.configure(:addr => @addr, :port => @port)
    end

    def teardown
      Client.unconfigure
    end

    def test_login_success
      Client.login(:username => @username, :password => @password)
      assert_instance_of(String, Client.default.get_login_session.key)
      assert_instance_of(String, Client.default.get_login_session.key_id)
      assert_instance_of(String, Client.default.get_login_session.algorithm)
      assert_instance_of(String, Client.default.get_login_session.bearer_token)
    end

    def test_who_am_I
      Client.login(:username => @username, :password => @password)
      me = Qumulo::Rest::V1::WhoAmI.get
      assert_equal(V1::User, me.class)
      assert_equal(@username, me.name)
    end

    def test_change_password
      begin
        Client.login(:username => @username, :password => @password)
        V1::SetPassword.post(:old_password => @username, :new_password => "p@55")
        me = Qumulo::Rest::V1::WhoAmI.get
        assert_equal(@username, me.name)

        # Cannot login using the old password
        Client.logout
        assert_raises AuthenticationError do
          Client.login(:username => @username, :password => @password)
        end
        assert_raises LoginRequired do
          Qumulo::Rest::V1::WhoAmI.get
        end

        # Log in with new password
        Client.login(:username => @username, :password => "p@55")
        me = Qumulo::Rest::V1::WhoAmI.get
        assert_equal(@username, me.name)

      ensure
        # Restore the normal @username password before test case is done
        Client.login(:username => @username, :password => "p@55")
        V1::SetPassword.post(:old_password => "p@55", :new_password => @username)
      end
    end

  end
end
