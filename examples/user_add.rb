#!/usr/bin/env ruby
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

require "rubygems"
require "qumulo/rest"
require "optparse"

class ApplicationMain

  def parse_options(args)
    parser = OptionParser.new do |opts|
      opts.banner  = "Usage: user_add.rb [options] new_login"
      opts.separator "       Add a new user to Qumulo cluster."
      opts.separator "Options:"
      opts.on("-i", "--ip ADDR", "[required] Address of Qumulo cluster") { |s| @addr = s }
      opts.on("-P", "--port PORT", "REST API port") { |n| @port = n.to_i }
      opts.on("-u", "--user NAME", "Login name") { |s| @username = s }
      opts.on("-p", "--password PW", "Login password") { |s| @password = s }
      opts.on("-d", "--uid UID", "Map new user to NFS user id") { |s| @uid = s }
      opts.on("-g", "--primary-group GID", "Add new user to given group") { |s| @primary_group = s }
      opts.separator "Example:"
      opts.separator "    user_add.rb -i 10.1.2.230 -u admin -p s3cr3t sandy"
      opts.separator ""
    end
    @new_user = parser.parse(args)[0]
  end

  def validate_arguments
    unless @addr and @new_user
      puts "ADDR and NEW_LOGIN are required arguments"
      exit 1
    end
    @port ||= 8000
    @username ||= "admin"
    @password ||= "admin"
  end

  def connect
    Qumulo::Rest::Client.configure(:addr => @addr, :port => @port)
    Qumulo::Rest::Client.login(:username => @username, :password => @password)
  end

  def get_users_group_id
    # If primary group is not given, add the user to Users group
    users = Qumulo::Rest::V1::Groups.get.items.select {|group| group.name == "Users"}[0]
    users.id
  end

  def create_user
    puts "Creating new user: #@new_user (NFS uid=#@uid) on cluster at #@addr:#@port"
    data = Qumulo::Rest::V1::User.new
    data.name = @new_user
    data.primary_group = @primary_group || get_users_group_id
    data.uid = @uid if @uid # only set it if given
    new_user = Qumulo::Rest::V1::Users.post(data)
    puts "User #@new_user [id=#{new_user.id}] created."
  end

  def run
    argv = parse_options(ARGV)
    validate_arguments
    connect
    create_user
  end

end

ApplicationMain.new.run

