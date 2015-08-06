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
