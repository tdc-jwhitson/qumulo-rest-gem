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

    # === Description
    # Set password for the given user.
    #
    # === Parameters
    # new_password:: String
    #
    def set_password(new_password)
      UserPassword.new(:id => id, :new_password => new_password).post
    end

    # === Description
    # Returns the list of groups that the user belongs to
    #
    # === Returns
    # An array of Group objects
    #
    def groups
      UserGroups.new(:id => id).get.items
    end
  end

  # == Class Description
  # Used to set password.
  #
  # == Supported Methods
  # POST
  #
  class UserPassword < Qumulo::Rest::Base
    uri_spec "/v1/auth/users/:id/setpassword"
    field :id, Bignum
    field :new_password, String
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

    # === Description
    # Returns the list of users that belong to the current group.
    #
    # === Returns
    # An array of User objects
    #
    def users
      GroupMembers.new(:id => id).get.items
    end

    # === Description
    # Add a user to the group
    #
    # === Parameters
    # user:: User object to add to the group
    #
    def add(user)
      GroupMembers.new(:id => id).post(user)
    end

    # === Description
    # Remove a user from the group
    #
    # === Parameters
    # user:: User object to remove from the group
    #
    def remove(user)
      GroupMember.new(:group_id => id, :member_id => user.id).delete
    end

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

  # == Class Description
  # This class is used to GET the list the users that belong to a group,
  # or add a user to a group via POST.
  #
  # == Supported Methods
  # GET, POST
  #
  class GroupMembers < Qumulo::Rest::BaseCollection
    uri_spec "/v1/auth/groups/:id/members/"
    field :id, Bignum    # group ID
    items User

    # === Description
    # Override the normal POST method to use the payload format required by
    # qfsd.
    #
    # === Parameters
    # member:: User object
    # request_opts:: Hash object to feed to RequstOptions constructor. (see RequestOptions)
    #                Or an instance of RequestOptions class.
    #
    # === Returns
    # User object
    #
    def post(member, request_opts={})
      unless member.is_a?(User)
        raise DataTypeError.new("User object is expected, but got [#{member.inspect}]")
      end
      member = GroupMember.new(:group_id => self.id, :member_id => member.id)
      http(request_opts).post(resolved_path, member.as_hash)
    end

  end

  # == Class Description
  # This class is used to remove a member from a group.
  #
  # == Supported Methods
  # DELETE
  #
  class GroupMember < Qumulo::Rest::Base
    uri_spec "/v1/auth/groups/:group_id/members/:member_id"
    field :group_id, Bignum   # group ID
    field :member_id, Bignum  # same as user ID
  end

  # == Class Description
  # This class is used to list the groups that a user belongs to.
  #
  # == Supported Methods
  # GET
  #
  class UserGroups < Qumulo::Rest::BaseCollection
    uri_spec "/v1/auth/users/:id/groups/"
    field :id, Bignum    # user ID
    items Group
  end

end
