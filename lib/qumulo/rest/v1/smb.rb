require "qumulo/rest/exception"
require "qumulo/rest/base"
require "qumulo/rest/base_collection"
module Qumulo::Rest
  module V1

    # == Class Description
    # Represents a single SMB share.
    #
    # == Supported Methods
    # GET, PUT, DELETE
    #
    class SmbShare < Qumulo::Rest::Base
      uri_spec "/v1/conf/shares/smb/:id"
      field :id, Bignum
      field :share_name, String
      field :fs_path, String
      field :description, String
      field :read_only, Boolean                  # read-only or not
      field :allow_guest_access, Boolean         # guest access or not
      query_param "allow-fs-path-create"
        # set "true" to create directory in fs_path if missing on server-side
    end

    # == Class Description
    # Represents the list of all SMB shares.
    #
    # == Supported Methods
    # GET, POST
    #
    class SmbShares < Qumulo::Rest::BaseCollection
      uri_spec "/v1/conf/shares/smb/"
      items SmbShare
    end

  end
end
