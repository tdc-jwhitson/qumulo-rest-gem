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
    @port = 8000
    @username = "admin"
    @password = "admin"
    parser = OptionParser.new do |opts|
      opts.banner  = "Usage: user_delete.rb [options] USERNAME"
      opts.separator "       Delete the given user from Qumulo cluster."
      opts.separator "Options:"
      opts.on("-i", "--ip ADDR", "[required] Address of Qumulo cluster") { |s| @addr = s }
      opts.on("-P", "--port PORT", "REST API port") { |n| @port = n.to_i }
      opts.on("-u", "--user NAME", "Login name") { |s| @username = s }
      opts.on("-p", "--password PW", "Login password") { |s| @password = s }
      opts.separator "Example:"
      opts.separator "    user_delete.rb -i 10.1.2.230 sandy"
      opts.separator ""
    end
    @to_delete = parser.parse(args)[0]
    unless @addr and @to_delete
      puts "ADDR and USERNAME are required arguments"
      exit 1
    end
  end

  def connect
    Qumulo::Rest::Client.configure(:addr => @addr, :port => @port)
    Qumulo::Rest::Client.login(:username => @username, :password => @password)
  end

  def delete_user
    found = Qumulo::Rest::V1::Users.get.items.select {|user| user.name == @to_delete}[0]
    if found
      puts "Deleting user: #@to_delete [id = #{found.id}]"
      found.delete
    else
      puts "User not found: #@to_delete"
    end
  end

  def run
    argv = parse_options(ARGV)
    connect
    delete_user
  end

end

ApplicationMain.new.run

