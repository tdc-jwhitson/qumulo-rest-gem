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
  class NfsExport < Qumulo::Rest::Base
    uri_spec "/v1/conf/shares/nfs/:id"
    field :id, Bignum
    field :export_path, String
    field :fs_path, String
    field :description, String
    field :restrictions
  end

  # == Class Description
  # Represents the list of all NFS exports.
  #
  # == Supported Methods
  # GET, POST
  #
  class NfsExports < Qumulo::Rest::BaseCollection
    uri_spec "/v1/conf/shares/nfs/"
    items NfsExport
  end

end
