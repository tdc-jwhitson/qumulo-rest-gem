require "qumulo/rest/exception"
require "qumulo/rest/base"
module Qumulo::Rest::V1

  # == Class Description
  # This resource is used to log in a client using :username and :password
  # attributes. After post, it will contain the :key to sign requests afterwards.
  #
  # == Notes
  # This is a non-standard REST resource, in that, the attributes used in POST,
  # namely, :username and :password, are different from the attributes returned
  # in a server response, namely, :key and :key_id. But, that's OK. We don't want
  # to keep around :username and :password in our login session object.
  #
  class LoginSession < Qumulo::Rest::Base

    uri_spec "/v1/login"

    # only used in post
    field :username, String
    field :password, String

    # used in server response
    field :key, String
    field :key_id, String
    field :algorithm, String
    field :bearer_token, String

    # === Description
    # Send the request to the server
    #
    def start
      begin
        post(:not_authorized => true)
      rescue Qumulo::Rest::RequestFailed => e
        raise Qumulo::Rest::AuthenticationError.new(
          "Login failed", self)
      end
    end

  end
end
