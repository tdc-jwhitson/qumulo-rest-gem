require 'test/unit'
require 'qumulo/rest'

class LoginTest < Test::Unit::TestCase

  def setup
    Qumulo::Rest::Client.configure(:host => "localhost", :port => 9705)
  end

  def test_login_success
    Qumulo::Rest::Client.login(:username => "admin", :password => "admin")
  end

end

