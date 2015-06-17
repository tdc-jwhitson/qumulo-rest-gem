require "qumulo/rest/exception"
require "qumulo/rest/base"
require "qumulo/rest/base_collection"
module Qumulo::Rest::V1

  # == Class Description
  # Represents a single user.
  # Supported methods: GET, PUT, DELETE
  #
  class User < Qumulo::Rest::Base
    uri_spec "/v1/auth/users/:id"
    field :id, String
    field :name, String
    field :primary_group, Bignum
    field :uid, Bignum
    field :sid, String
  end

  # == Class Description
  # Represents the list of all users.
  # Supported methods: GET, POST
  #
  class Users < Qumulo::Rest::BaseCollection
    uri_spec "/v1/auth/users/"
    items User
  end

  # == Class Description
  # Get the current user.
  # Supported methods: GET
  #
  class WhoAmI < Qumulo::Rest::Base
    uri_spec "/v1/who-am-i"
    result User
  end

  # == Class Description
  # Changes the password for logged-in user.
  # Supported methods: POST.
  #
  class SetPassword < Qumulo::Rest::Base
    uri_spec "/v1/setpassword"
    field :old_password
    field :new_password
  end

end
