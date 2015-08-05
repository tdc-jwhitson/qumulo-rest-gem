require 'minitest/autorun'
require 'test_env'
require 'qumulo/rest'
require 'qumulo/rest/v1/nfs'

module Qumulo::Rest::V1
  class NfsTest < Minitest::Test
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

      # Template for creating new NFS exports
      @template = NfsExport.new(
                  :export_path => "/" + with_test_prefix("NFS1"),
                  :fs_path => "/" + with_test_prefix("NFS1"),
                  :description => with_test_prefix("my first NFS export"),
                  :restrictions => [
                    NfsRestriction.new(
                      :host_restrictions => [],
                      :read_only => false,
                      :user_mapping => NFS_MAP_NONE,
                      :map_to_user_id => 0)
                  ])
      @template.allow_fs_path_create = "true"
    end

    def teardown
      clean_up_integration_test_objects
      Qumulo::Rest::Client.unconfigure
    end

    # Create exports, list them, update them, and then delete them
    def test_nfs_export_crud

      # Create a new NFS export
      nfs_export = NfsExports.post(@template)

      # Read NFS export
      nfs_export = NfsExport.get(:id => nfs_export.id)
      assert_equal(1, nfs_export.restrictions.length)

      # Update the NFS export with new NFS restrictions, and save it to server
      nfs_export.description = "XXX"
      nfs_export.restrictions.insert(0, NfsRestriction.new(
          :host_restrictions => [ "1.1.1.1" ],
          :read_only => true,
          :user_mapping => NFS_MAP_NONE,
          :map_to_user_id => 0))
      assert_equal(2, nfs_export.restrictions.length)
      assert_equal("1.1.1.1", nfs_export.restrictions[0].host_restrictions[0])
      assert_equal(nil, nfs_export.restrictions[1].host_restrictions[0])
      nfs_export.put

      # Get it to validate it
      nfs_export2 = NfsExport.get(:id => nfs_export.id)
      assert_equal(nfs_export.as_hash, nfs_export2.as_hash)
      assert_equal(nfs_export, nfs_export2)

      # Delete the NFS export
      nfs_export2.delete

    end

    def test_nfs_export_list
      exports = NfsExports.get
      original_length = exports.items.length
      nfs_export = NfsExports.post(@template)

      # We should have one more NFS export
      exports = NfsExports.get
      assert_equal(original_length + 1, exports.items.length)

      # We should have one less after deleting
      nfs_export.delete
      exports = NfsExports.get
      assert_equal(original_length, exports.items.length)
    end

  end
end
