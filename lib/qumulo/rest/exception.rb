module Qumulo::Rest

  # === Descript
  # Base error class; we store the an additional context object that can be
  # convenient to look at when an error gets thrown
  #
  class ErrorBase < RuntimeError
    attr_reader :contect
    def initialize(msg, context = nil)
      super(msg)
      @context = context
    end
  end

  # === Description
  # Invalid client configuration
  #
  class ConfigError < ErrorBase; end

  # === Description
  # Passed argument is not valid
  #
  class ValidationError < ErrorBase; end

  # === Description
  # Operation attempted without successful login
  #
  class LoginRequired < ErrorBase; end

  # === Description
  # There was authentication problem during login
  #
  class AuthenticationError < ErrorBase; end

  # === Description
  # Errors related to generation of URL
  #
  class UriError < ErrorBase; end

  # === Description
  # No data has been retrieved yet.
  #
  class NoData < ErrorBase; end

  # === Description
  # Type error when using accessors against Base class.
  #
  class DataTypeError < ErrorBase; end

  # === Description
  # REST response mismatched expected structure according to resource class definion.
  #
  class ResourceMismatchError < ErrorBase; end

  # === Description
  # HTTP request failed. Use obj.response to check against the failure type;
  # The context is set to the corresponding response object.
  # Example code:
  #
  #   begin
  #     user.put!
  #   rescue Qumulo::Rest::RequetFailed => e
  #     if e.context.is_a?(Net::HTTPForbidden)
  #       # do somehting to obtain permission
  #     end
  #   end
  #
  class RequestFailed < ErrorBase; end

  # === Description
  # Errors deliberately caused by a test or just a badly written test
  #
  class TestError < ErrorBase; end

end

