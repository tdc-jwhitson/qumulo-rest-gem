require 'test/unit'
require 'test_env'
require 'qumulo/rest'
require 'qumulo/rest/v1/smb'

module Qumulo::Rest::V1
  class SmbTest < Test::Unit::TestCase
    include Qumulo::Rest::TestEnv

    def clean_up_integration_test_objects
      SmbShares.get.items.each do |share|
        if has_test_prefix?(share.description)
          share.delete
        end
      end
    end

    def setup
      connection_params_from_env # sets @username, @password, @addr, @port
      Qumulo::Rest::Client.configure(:addr => @addr, :port => @port)
      Qumulo::Rest::Client.login(:username => @username, :password => @password)
      clean_up_integration_test_objects

      # Template for creating new shares
      @share_name = with_test_prefix("SMB1")
      @share_desc = with_test_prefix("my first SMB share share")
      @template = SmbShare.new(
                  :share_name => @share_name,
                  :fs_path => "/" + @share_name,
                  :description => @share_desc,
                  :read_only => false,
                  :allow_guest_access => true)
      @template.allow_fs_path_create = "true"
    end

    def teardown
      clean_up_integration_test_objects
      Qumulo::Rest::Client.unconfigure
    end

    # Create shares, list them, update them, and then delete them
    def test_smb_share_crud

      # Create a new SMB share
      smb_share = SmbShares.post(@template)

      # Read SMB share
      smb_share = SmbShare.get(:id => smb_share.id)
      assert_equal(@share_name, smb_share.share_name)
      assert_equal(@share_desc, smb_share.description)

      # Update the SMB share description
      smb_share.description = "XXX"
      smb_share.put

      # Get it to validate it
      smb_share2 = SmbShare.get(:id => smb_share.id)
      assert_equal("XXX", smb_share.description)

      # Delete the SMB share
      smb_share2.delete

    end

    def test_smb_share_list
      shares = SmbShares.get
      original_length = shares.items.length
      smb_share = SmbShares.post(@template)

      # We should have one more share
      shares = SmbShares.get
      assert_equal(original_length + 1, shares.items.length)

      # We should have one less after deleting
      smb_share.delete
      shares = SmbShares.get
      assert_equal(original_length, shares.items.length)
    end

  end
end
