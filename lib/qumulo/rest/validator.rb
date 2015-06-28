require "qumulo/rest/exception"
module Qumulo::Rest
  module Validator

    def error_msg(name, arg, msg)
      "#{name} (#{arg.inspect}): " + msg
    end

    def validate_instance_of(name, arg, typ)
      unless arg.is_a?(typ)
        raise ValidationError.new(
          error_msg(name, arg, "is not instance of #{typ})"))
      end
    end

    def validated_string(name, arg)
      validate_instance_of(name, arg, String)
      arg
    end

    def validated_non_empty_string(name, arg)
      str = validated_string(name, arg)
      if str.empty?
        raise ValidationError.new(
          error_msg(name, arg, "is empty"))
      end
      arg
    end

    def validated_positive_int(name, arg)
      validate_instance_of(name, arg, Integer)
      if arg < 0
        raise ValidationError.new(
          error_msg(name, arg, "is not a positive integer"))
      end
      arg
    end

    HTTP_METHODS = [:post, :put, :get, :delete]
    def validated_method_sym(name, arg)
      if not HTTP_METHODS.include?(arg)
        raise ValidationError.new(
          error_msg(name, arg, "must be one of #{HTTP_METHODS}"))
      end
      arg
    end

  end
end
