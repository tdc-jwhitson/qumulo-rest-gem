module Qumulo::Rest

  # === Descript
  # Base error class; we store the an additional context object that can be
  # convenient to look at when an error gets thrown
  #
  class ErrorBase < RuntimeError
    def initialize(msg, context = nil)
      super(msg)
      @context = context
    end
  end

  # === Description
  # Passed argument is not valid
  #
  class ArgumentError < ErrorBase; end

  # === Description
  # There was a problem with authentication
  #
  class AuthenticationError < ErrorBase; end

  # === Description
  # Errors related to generation of URL
  #
  class UrlError < ErrorBase; end

end

