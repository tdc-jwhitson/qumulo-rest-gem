# Qumulo::Rest

This is a client library to access Qumulo Core appliance via REST API.

## Installation

Add this line to your application's Gemfile:

    gem 'qumulo-rest'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install qumulo-rest

## Usage

TODO: Write usage instructions here

## Developer instructions

Once you have cloned this repository, you need to do the following to start developing this gem.
The following instructions will work well if you set up your ruby development environment using rbenv (https://github.com/sstephenson/rbenv)

This gem is developed to support old version of ruby 1.8.7, and makes minimal use of any external modules on purpose.

1. Install bundler:
   gem install bundler

2. Complete the bundle (install necessary gems):
   bundle install

3. To build this gem:
   bundle exec rake build

4. To run unit tests:
   bundle exec rake test

5. To run integration tests:
   bundle exec rake integration QUMULO_ADDR=[addr] QUMULO_PORT=[port]

   If unspecified, addr defaults to 'localhost', and port defaults to 8000.

6. To list other rake tasks:
   bundle exec rake -T

Please don't use rake release command!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

