module Qumulo
  module Rest
    require "qumulo/rest/gem_version"
    require "qumulo/rest/exception"
    require "qumulo/rest/validator"
    require "qumulo/rest/client"
    require "qumulo/rest/base"

    # REST API v1
    module V1
      require "qumulo/rest/v1/user"
      require "qumulo/rest/v1/version"
    end

  end
end

