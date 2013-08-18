require "qumulo/rest/exception"
require "qumulo/rest/base"
module Qumulo::Rest

  # == Class Description
  # User resource implementation.
  #
  class User < Base
    path "/users/:id"
  end

end
