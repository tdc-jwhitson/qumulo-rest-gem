require 'test/unit'
require 'test_env'
require 'qumulo/rest'
require 'qumulo/rest/v1/nfs'

module Qumulo::Rest::V1
  class NfsTest < Test::Unit::TestCase
    include Qumulo::Rest::TestEnv

    def clean_up_integration_test_objects
    end

    def setup
      connection_params_from_env # sets @username, @password, @addr, @port
      Qumulo::Rest::Client.configure(:addr => @addr, :port => @port)
      Qumulo::Rest::Client.login(:username => @username, :password => @password)

      clean_up_integration_test_objects
    end

    def teardown
      clean_up_integration_test_objects
      Qumulo::Rest::Client.unconfigure
    end

    # Create exports, list them, update them, and then delete them
    def test_user_crud
    end

  end
end
