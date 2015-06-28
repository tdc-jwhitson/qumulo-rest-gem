require 'test/unit'
require 'test_env'
require 'qumulo/rest'

module Qumulo::Rest
  class LoginTest < Test::Unit::TestCase
    include Qumulo::Rest::ReadEnv

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
        assert_raise AuthenticationError do
          Client.login(:username => @username, :password => @password)
        end
        assert_raise LoginRequired do
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
