require "qumulo/rest/exception"
require "qumulo/rest/base"
require "qumulo/rest/base_collection"
module Qumulo::Rest::V1

  # == Class Description
  # Represents a single user.
  #
  # == Supported Methods
  # GET, PUT, DELETE
  #
  class User < Qumulo::Rest::Base
    uri_spec "/v1/auth/users/:id"
    field :id, Bignum
    field :name, String
    field :primary_group, Bignum
    field :uid, Bignum       # NFS uid
    field :sid, String
  end

  # == Class Description
  # Represents the list of all users known by the cluster.
  #
  # == Supported Methods
  # GET, POST
  #
  class Users < Qumulo::Rest::BaseCollection
    uri_spec "/v1/auth/users/"
    items User
  end

  # == Class Description
  # Get the current user.
  #
  # == Supported Methods
  # GET
  #
  class WhoAmI < Qumulo::Rest::Base
    uri_spec "/v1/who-am-i"
    result User
  end

  # == Class Description
  # Changes the password for logged-in user.
  #
  # == Supported Methods
  # POST
  #
  class SetPassword < Qumulo::Rest::Base
    uri_spec "/v1/setpassword"
    field :old_password
    field :new_password
  end

  # == Class Description
  # Represents the list of members of the given group
  #
  # == Supported Methods
  # GET, POST
  #
  class GroupMembers < Qumulo::Rest::BaseCollection
    uri_spec "/v1/auth/groups/:id/members/"
    field :id, Bignum
    items User

    # === Description
    # Override the normal POST method to use the payload format required by
    # qfsd.
    #
    # === Parameters
    # payload:: New member to create.  You can pass a User object, or
    #           a simple hash that has the following format:
    #           {
    #             :group_id => <group id integer>,
    #             :user_id => <user ID integer> }
    #           }
    # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
    #                Or an instance of RequestOptions class.
    #
    # === Returns
    # User object
    #
    def post(payload, request_opts={})

      if payload.is_a?(User)
        payload = { :group_id => self.id, :user_id => payload.id }
      else
        if payload.is_a?(Hash)
          unless payload[:group_id].is_a?(Integer)
            raise DataTypeError.new("Hash object missing :group_id field")
          end
          unless payload[:user_id].is_a?(Integer)
            raise DataTypeError.new("Hash object missing :user_id field")
          end
        else
          raise DataTypeError.new("User object or a Hash object required")
        end
      end

      http(request_opts).post(resolved_path, payload)
    end

  end

  # == Class Description
  # Represents a group.
  #
  # == Supported Methods
  # GET, PUT, DELETE
  #
  class Group < Qumulo::Rest::Base
    uri_spec "/v1/auth/groups/:id"
    field :id, Bignum
    field :name, String
    field :gid, String # NFS gid (XXX steve - this should be Integer, like uid, but it's not)
    field :sid, String
  end

  # == Class Description
  # Represents the list of all groups known by the cluster.
  #
  # == Supported Methods
  # GET, POST
  class Groups < Qumulo::Rest::BaseCollection
    uri_spec "/v1/auth/groups/"
    items Group
  end

end
