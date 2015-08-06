#
#  Copyright 2015 Qumulo, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

require "qumulo/rest/exception"
require "qumulo/rest/base"
require "qumulo/rest/base_collection"
module Qumulo::Rest
  module V1

    # Values to use for user_mapping field of NfsRestriction
    NFS_MAP_NONE = "NFS_MAP_NONE"
    NFS_MAP_ROOT = "NFS_MAP_ROOT"
    NFS_MAP_ALL  = "NFS_MAP_ALL"

    # == Class Description
    # A component in a NfsExport resource.  An array of these are used to describe
    # NFS restrictions.  This is not a stand-alone REST resource, and does not
    # have any uri_spec.
    #
    class NfsRestriction < Qumulo::Rest::Base
      field :host_restrictions, array_of(String) # An array of network ranges to match
      field :read_only, Boolean                  # read-only or not
      field :user_mapping, String                # One of the defined enum values
      field :map_to_user_id, Bignum              # User ID, set 0 if user_mapping is NFS_MAP_NONE
    end

    # == Class Description
    # Represents a single NFS export.
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
      field :restrictions, array_of(NfsRestriction)
      query_param "allow-fs-path-create"
        # set "true" to create directory in fs_path if missing on server-side
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
end
