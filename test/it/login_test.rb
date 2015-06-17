require 'test/unit'
require 'qumulo/rest'

module Qumulo::Rest
  class LoginTest < Test::Unit::TestCase

    def setup
      addr = ENV['QUMULO_ADDR'] || "localhost"
      port = (ENV['QUMULO_PORT'] || 8000).to_i
      Client.configure(:addr => addr, :port => port)
    end

    def teardown
      Client.unconfigure
    end

    def test_login_success
      Client.login(:username => "admin", :password => "admin")
      assert_instance_of(String, Client.default.get_login_session.key)
      assert_instance_of(String, Client.default.get_login_session.key_id)
      assert_instance_of(String, Client.default.get_login_session.algorithm)
      assert_instance_of(String, Client.default.get_login_session.bearer_token)
    end

    def test_who_am_I
      Client.login(:username => "admin", :password => "admin")
      me = Qumulo::Rest::V1::WhoAmI.get
      assert_equal(V1::User, me.class)
      assert_equal("admin", me.name)
    end

    def test_change_password
      begin
        Client.login(:username => "admin", :password => "admin")
        V1::SetPassword.post(:old_password => "admin", :new_password => "p@55")
        me = Qumulo::Rest::V1::WhoAmI.get
        assert_equal("admin", me.name)

        # Cannot login using the old password
        Client.logout
        assert_raise AuthenticationError do
          Client.login(:username => "admin", :password => "admin")
        end
        assert_raise LoginRequired do
          Qumulo::Rest::V1::WhoAmI.get
        end

        # Log in with new password
        Client.login(:username => "admin", :password => "p@55")
        me = Qumulo::Rest::V1::WhoAmI.get
        assert_equal("admin", me.name)

      ensure
        # Restore the normal "admin" password before test case is done
        Client.login(:username => "admin", :password => "p@55")
        V1::SetPassword.post(:old_password => "p@55", :new_password => "admin")
      end
    end

  end
end
