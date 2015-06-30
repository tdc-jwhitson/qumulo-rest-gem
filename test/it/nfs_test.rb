require 'test/unit'
require 'test_env'
require 'qumulo/rest'
require 'qumulo/rest/v1/nfs'

module Qumulo::Rest::V1
  class NfsTest < Test::Unit::TestCase
    include Qumulo::Rest::TestEnv

    def clean_up_integration_test_objects
      NfsExports.get.items.each do |export|
        if has_test_prefix?(export.description)
          export.delete
        end
      end
    end

    def setup
      connection_params_from_env # sets @username, @password, @addr, @port
      Qumulo::Rest::Client.configure(:addr => @addr, :port => @port)
      Qumulo::Rest::Client.login(:username => @username, :password => @password)

      clean_up_integration_test_objects
    end

    def teardown
      clean_up_integration_test_objects
      Qumulo::Rest::Client.unconfigure
    end

    # Create exports, list them, update them, and then delete them
    def test_nfs_export_crud

      # Create a new NFS export
      template = NfsExport.new(
                  :export_path => "/" + with_test_prefix("NFS1"),
                  :fs_path => "/" + with_test_prefix("NFS1"),
                  :description => with_test_prefix("my first NFS export share"),
                  :restrictions => [
                    NfsRestriction.new(
                      :host_restrictions => [],
                      :read_only => false,
                      :user_mapping => NFS_MAP_NONE,
                      :map_to_user_id => 0)
                  ])
      template.allow_fs_path_create = "true"
      nfs_export = NfsExports.post(template)

      # Read NFS export
      nfs_export = NfsExport.get(:id => nfs_export.id)
      assert_equal(1, nfs_export.restrictions.length)

      # Update the NFS export with new NFS restrictions

      # Delete the NFS export

    end

  end
end
