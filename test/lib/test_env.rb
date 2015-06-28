module Qumulo::Rest
  module ReadEnv
    def connection_params_from_env
      @username = ENV['QUMULO_USER'] || "admin"
      @password = ENV['QUMULO_PASS'] || "admin"
      @addr = ENV['QUMULO_ADDR'] || "localhost"
      @port = (ENV['QUMULO_PORT'] || 8000).to_i
    end
  end
end
