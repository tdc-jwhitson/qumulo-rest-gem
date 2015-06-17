require "qumulo/rest/exception"
require "qumulo/rest/base"
module Qumulo::Rest::V1

  # == Class Description
  # User resource implementation.
  #
  class User < Qumulo::Rest::Base
    uri_spec "/v1/auth/users/:id"
    field :id, String
    field :sid, String
    field :primary_group, String
    field :name, String
    field :uid, String
  end

  # == Class Description
  # Enquire the current user.
  #
  class WhoAmI < Qumulo::Rest::Base
    uri_spec "/v1/who-am-i"
    result User
  end
end
