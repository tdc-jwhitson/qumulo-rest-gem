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
    end

  end
end
