module Qumulo::Rest

  module TestEnv

    # Utility for adding/checking test prefix string
    #

    INTEGRATION_TEST_PREFIX = "integration_test_"

    def with_prefix(name)
      INTEGRATION_TEST_PREFIX + name
    end

    def has_prefix?(name)
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

  end

end
