require "qumulo/rest/exception"
require "qumulo/rest/base"
module Qumulo::Rest::V1

  # == Class Description
  # Get the version of the appliance
  #
  class Version < Qumulo::Rest::Base
    uri_spec "/v1/version"
  end

end
