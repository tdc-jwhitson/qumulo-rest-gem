require "qumulo/rest/exception"
require "qumulo/rest/base"
module Qumulo::Rest

  # == Class Description
  # This resource is used to log in a client.
  # After post, it will contain the key to sign requests afterwards.
  #
  class Login < Base

    path "/login"

    # === Description
    # Send the request to the server
    #
    def execute
      http_post(:no_sign => true)
      throw AuthenticationError.new("Login failed", self) if @error
    end

  end
end
