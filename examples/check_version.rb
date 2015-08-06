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
    parser = OptionParser.new do |opts|
      opts.banner  = "Usage: check_version.rb [options]"
      opts.separator "       Check Qumulo cluster version."
      opts.separator "Options:"
      opts.on("-i", "--ip ADDR", "[required] Address of Qumulo cluster") { |s| @addr = s }
      opts.on("-P", "--port PORT", "REST API port") { |n| @port = n.to_i }
      opts.separator "Example:"
      opts.separator "    check_version.rb -i 10.1.2.230"
      opts.separator ""
    end
    parser.parse(args)
    unless @addr
      puts "Cluster ADDR is required"
      exit 1
    end
  end

  def run
    parse_options(ARGV)
    # Version is a REST resource that does not require login
    # For these, you need to pass {:not_authorized => true} to set special request option
    Qumulo::Rest::Client.configure(:addr => @addr, :port => @port)
    version = Qumulo::Rest::V1::Version.get({}, {:not_authorized => true})
    header = "Qumulo Cluster Version [address=#@addr]"
    puts
    puts header
    puts "-" * header.length
    puts "revision_id: #{version.revision_id}"
    puts "build_id:    #{version.build_id}"
    puts "build_date:  #{version.build_date.strftime("%A, %d %b %Y %l:%M %p")}"
    puts
  end

end

ApplicationMain.new.run

