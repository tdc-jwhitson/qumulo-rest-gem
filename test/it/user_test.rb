require 'test/unit'
require 'qumulo/rest'
require 'qumulo/rest/v1/user'

module Qumulo::Rest::V1
  class LoginTest < Test::Unit::TestCase

    INTEGRATION_TEST_PREFIX = "integration test object "

    def with_prefix(name)
      "integration test " + name
    end

    def has_prefix?(name)
      name =~ /^integration test /
    end

    def clean_up_integration_test_objects
      Users.get.items.each do |user|
        if has_prefix?(user.name)
          user.delete
        end
      end
      Groups.get.items.each do |group|
        if has_prefix?(group.name)
          group.delete
        end
      end
    end

    def setup
      addr = ENV['QUMULO_ADDR'] || "localhost"
      port = (ENV['QUMULO_PORT'] || 8000).to_i
      Qumulo::Rest::Client.configure(:addr => addr, :port => port)
      Qumulo::Rest::Client.login(:username => "admin", :password => "admin")

      # Figure out the users group and admin group for use in test cases
      Groups.get.items.each do |group|
        case group.name
        when "Users"
          @users_group_id = group.id
        when "Guests"
          @guests_group_id = group.id
        end
      end
      clean_up_integration_test_objects
    end

    def teardown
      clean_up_integration_test_objects
      Qumulo::Rest::Client.unconfigure
    end

    # Create users, list them, update them, and then delete them
    def test_user_crud

      # Create by posting a Hash to collection class
      user = Users.post(:name => with_prefix("richard"), :primary_group => 513)
      user_1_id = user.id

      # Create by posting an instance to collection class
      template = User.new(:name => with_prefix("becky"), :primary_group => 513)
      user = Users.post(template)
      user_2_id = user.id

      # Read using collection
      user_1 = Users.get.items.select {|u| u.id == user_1_id}[0]
      assert_equal(with_prefix("richard"), user_1.name)
      assert_equal(513, user_1.primary_group)
      assert_equal(0, user_1.uid)

      # Read using class
      user_2 = User.get(:id => user_2_id)
      assert_equal(with_prefix("becky"), user_2.name)
      assert_equal(513, user_2.primary_group)
      assert_equal(0, user_2.uid)

      # Update using instance (uses the ETAG)
      user_1.uid = 499
      user_1.put
      user_1 = User.get(:id => user_1_id)
      assert_equal(user_1_id, user_1.id)
      assert_equal(with_prefix("richard"), user_1.name)
      assert_equal(513, user_1.primary_group)
      assert_equal(499, user_1.uid)

      # Update using class (no ETAG is applied)
      User.put(:id => user_2_id, :name => with_prefix("becky"),
        :primary_group => 513, :uid => 498)
      user_2 = User.get(:id => user_2_id)
      assert_equal(user_2_id, user_2.id)
      assert_equal(with_prefix("becky"), user_2.name)
      assert_equal(513, user_2.primary_group)
      assert_equal(498, user_2.uid)

      # Delete using instance or class
      user_1.delete
      User.delete(:id => user_2.id)

      # Verify that users were deleted
      Users.get.items.each do |user|
        assert_not_equal(user.id, user_1.id)
        assert_not_equal(user.id, user_2.id)
      end

    end

    def test_group_crud

      # Create by posting a Hash to collection class
      group = Groups.post(:name => with_prefix("G1"))
      group_1_id = group.id

      # Create by posting an instance to collection class
      template = Group.new(:name => with_prefix("G2"))
      group = Groups.post(template)
      group_2_id = group.id

      # Read using collection
      group_1 = Groups.get.items.select {|group| group.id == group_1_id}[0]
      assert_equal(with_prefix("G1"), group_1.name)
      assert_equal("", group_1.gid)

      # Read using class
      group_2 = Group.get(:id => group_2_id)
      assert_equal(with_prefix("G2"), group_2.name)
      assert_equal("", group_2.gid)

      # Update using instance (uses the ETAG)
      group_1.gid = "499"
      group_1.put
      group_1 = Group.get(:id => group_1_id)
      assert_equal(group_1_id, group_1.id)
      assert_equal(with_prefix("G1"), group_1.name)
      assert_equal("499", group_1.gid)

      # Update using class (no ETAG is applied)
      Group.put(:id => group_2_id, :name => with_prefix("G2"), :gid => "498")
      group_2 = Group.get(:id => group_2_id)
      assert_equal(group_2_id, group_2.id)
      assert_equal(with_prefix("G2"), group_2.name)
      assert_equal("498", group_2.gid)

      # Delete using instance or class
      group_1.delete
      Group.delete(:id => group_2.id)

      # Verify that groups were deleted
      Groups.get.items.each do |group|
        assert_not_equal(group.id, group_1.id)
        assert_not_equal(group.id, group_2.id)
      end

    end

    def test_etag_mismatch

      # Create user
      user = Users.post(:name => with_prefix("richard"), :primary_group => 513)
      user_1_id = user.id

      # Read user (we are about to update user 1)
      user_1_a = User.get(:id => user_1_id)
      user_1_a.uid = 680

      # Another client updates user 1
      user_1_b = User.get(:id => user_1_id)
      user_1_b.name = with_prefix("richard III")
      user_1_b.put
      user_1_b = User.get(:id => user_1_id)
      assert_equal(with_prefix("richard III"), user_1_b.name)

      # Trying to update the same user with out-of-date etag should fail
      assert_raise Qumulo::Rest::RequestFailed do
        user_1_a.put
      end

      # Make sure that uid was never updated on the server-side
      user_1_c = User.get(:id => user_1_id)
      assert_equal(0, user_1_c.uid)

    end

    def test_user_add_remove_group
    end

    def test_group_add_remove_user
    end

  end
end
