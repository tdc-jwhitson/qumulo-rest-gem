require "test/unit"
require "date"
require "fake_http"
require "net/http"

require "qumulo/rest/exception"
require "qumulo/rest/base"
require "qumulo/rest/base_collection"

module Qumulo::Rest

  class Fan < Qumulo::Rest::Base
    uri_spec "/v1/fans/:id"
    field :id, String
    field :name, String
  end

  class Fans < Qumulo::Rest::BaseCollection
    uri_spec "/v1/fans/"
    items Fan, :field => :fans
    field :total, Bignum
    field :page, Integer
    field :page_size, Integer
    field :next, String
    field :prev, String
  end

  class Song < Qumulo::Rest::Base
    uri_spec "/v1/albums/:album/songs/:id"
    field :id, String
    field :album, String
    field :title, String
    field :lyrics, String
    field :artist, String
  end

  class Songs < Qumulo::Rest::BaseCollection
    uri_spec "/v1/albums/:album/songs/"
    field :album, String
    items Song
  end

  class SongOfTheDay < Qumulo::Rest::Base
    uri_spec "/v1/song-of-the-day"
    result Song
  end

  class Album < Qumulo::Rest::Base
    uri_spec "/v1/albums/:id"
    field :id, String
    field :title, String
    field :release, DateTime
    field :money_earned, Bignum
    field :song_count, Integer
    field :songs, Array
    field :meta, Hash
    field :random
    field :biggest_fan, Fan
    field :best_song, Song
  end

  class BaseTest < Test::Unit::TestCase

    def setup
      FakeHttp.set_fake_response(:post, "/v1/login", {
        :code => 203,
        :attrs => {
          "key" => "fake-key",
          "key_id" => "fake-key-id",
          "algorithm" => "fake-algorithm",
          "bearer_token" => "1:fake-token"
        }})
      Client.configure(:http_class => FakeHttp)
      Client.login(:username => "fakeuser", :password => "fakepass")
    end

    def teardown
      Client.unconfigure
    end

    def test_accessors_success
      album = Album.new(:id => "10", :title => "Looking For Nemo",
                        :release => DateTime.parse("2015-06-01T12:00:00.123456789Z"),
                        :money_earned => 10000000000000000000000000000000000,
                        :song_count => 3, :songs => ["ding", "dong", "there"],
                        :meta => {"info" => "something", "publisher" => "dd"},
                        :biggest_fan => Fan.new("id" => "30", "name" => "Bonny"),
                        :best_song => Song.new("album" => "10", "title" => "ding",
                          "lyrics" => "ding ding ding", "artist" => "Sting")
                        )
      # URI
      assert_equal("/v1/albums/:id", Album.get_uri_spec)
      assert_equal("/v1/albums/10", album.resolved_path)

      # Attribute getters
      assert_equal("10", album.id)
      assert_equal("Looking For Nemo", album.title)
      assert_equal(DateTime.parse("2015-06-01T12:00:00.123456789Z"), album.release)
      assert_equal(10000000000000000000000000000000000, album.money_earned)
      assert_equal(3, album.song_count)
      assert_equal(["ding", "dong", "there"], album.songs)
      assert_equal({"info" => "something", "publisher" => "dd"}, album.meta)

      fan = album.biggest_fan
      assert_equal("30", fan.id)
      assert_equal("Bonny", fan.name)

      song = album.best_song
      assert_equal("10", song.album)
      assert_equal("ding", song.title)
      assert_equal("ding ding ding", song.lyrics)
      assert_equal("Sting", song.artist)

      # Attribute setters
      album.title = "New Sun"
      album.release = DateTime.parse("2016-01-01T08:00:00.987654321Z")
      album.money_earned = 20000
      album.song_count = 2
      album.songs = ["going", "down"]
      album.meta = {"info" => "not much"}
      album.random = 12

      fan.id = "40"
      fan.name = "f"
      album.biggest_fan = fan

      song.title = "who"
      song.lyrics = "who who who"
      album.best_song = song

      # JSON representation
      assert_equal({
        "id" => "10", "title" => "New Sun",             # String is stored as String
        "release" => "2016-01-01T08:00:00.987654321Z",  # DateTime is stored as String
        "money_earned" => "20000",                      # Bignum is stored as String
        "song_count" => 2,                              # Fixnum is stored as Integer
        "songs" => ["going", "down"],                   # Array is stored as is
        "meta" => {"info"=>"not much"},                 # Hash is stored as is
        "random" => 12,                                 # no type means no validation
        "biggest_fan" => {"id" => "40", "name" => "f"}, # Base-derived objects turn into Hash
        "best_song" => {"album" => "10",
            "title" => "who", "lyrics" => "who who who",
            "artist" => "Sting"}
        },
        album.as_hash)
    end

    def test_accessors_failure
      album = Album.new()

      # non-String not accepted
      assert_raise Qumulo::Rest::DataTypeError do
        album.id = 10
      end

      # non-DateTime not accepted
      assert_raise Qumulo::Rest::DataTypeError do
        album.release = "2016-01-01T08:00:00.987654321Z"
      end

      # non-Integer not accepted
      assert_raise Qumulo::Rest::DataTypeError do
        album.money_earned = "20000"
      end

      # non-Integer not accepted
      assert_raise Qumulo::Rest::DataTypeError do
        album.song_count = true
      end

      # non-Array not accepted
      assert_raise Qumulo::Rest::DataTypeError do
        album.songs = "going"
      end

      # non-Hash not accepted
      assert_raise Qumulo::Rest::DataTypeError do
        album.meta = ["going"]
      end

      # non-Object not accepted
      assert_raise Qumulo::Rest::DataTypeError do
        album.biggest_fan = {"id" => "40", "name" => "f"}
      end

      # Anything is accepted if type is not specified
      album.random = 10
      album.random = "10"
      album.random = DateTime.now
      album.random = [1, 2, 3]
      album.random = {"grocery" => "ok"}
    end

    def test_error
      album = Album.new()

      # Storing good result clears the error
      assert_raise Qumulo::Rest::RequestFailed do
        album.store_result({
          :response => Net::HTTPResponse.new("1.1", 503, "test error"),
          :code => 503,
          :error => {
            :message => "Simulated request failure"
          }
        })
      end
      assert_equal(503, album.code)
      assert_equal(true, album.error?)

      # Storing good result clears the error
      album.store_result({
        :response => Net::HTTPResponse.new("1.1", 200, "OK"),
        :code => 200,
        :attrs => {
            :id => "10", :title => "Looking For Nemo",
            :release => "2015-06-01T12:00:00.123456789Z",
            :money_earned => "10000000000000000000000000000000000"
        }})
      assert_equal(200, album.code)
      assert_equal(false, album.error?)

    end

    def test_result_class
      FakeHttp.set_fake_response(:get, "/v1/song-of-the-day", {
        :code => 200,
        :attrs => {"id" => "102", "album" => "10", "title" => "Hello",
                   "lyrics" => "Hello Hello Hello", "artist" => "monkey"}
        })
      song = SongOfTheDay.get
      assert_equal(Song, song.class)
      assert_equal("102", song.id)
      assert_equal("Hello", song.title)
      assert_equal("monkey", song.artist)
    end

  end

  class BaseCollectionTest < Test::Unit::TestCase

    def setup
      FakeHttp.set_fake_response(:post, "/v1/login", {
        :code => 203,
        :attrs => {
          "key" => "fake-key",
          "key_id" => "fake-key-id",
          "algorithm" => "fake-algorithm",
          "bearer_token" => "1:fake-token"
        }})
      Client.configure(:http_class => FakeHttp)
      Client.login(:username => "fakeuser", :password => "fakepass")
    end

    def teardown
      Client.unconfigure
    end

    def test_bare_array_collection_success
      songs = Songs.new()

      songs.store_result({
        :response => Net::HTTPResponse.new("1.1", 200, "OK"),
        :code => 200,
        :attrs => [
          {"id" => "10", "album" => "10", "title" => "A", "lyrics" => "AA", "artist" => "S1"},
          {"id" => "11", "album" => "10", "title" => "B", "lyrics" => "BB", "artist" => "S1"},
          {"id" => "12", "album" => "10", "title" => "C", "lyrics" => "CC", "artist" => "S2"}
        ]})

      # Verify that a collection returns instances of items class
      songs.items.each do |song|
        assert_equal(Song, song.class)
      end

      # Using instance accessors
      titles = songs.items.collect {|song| song.title}
      assert_equal(["A", "B", "C"], titles)
    end

    def test_bare_array_collection_failure
      songs = Songs.new()

      # Mismatching expectation: Hash vs Array
      assert_raise Qumulo::Rest::ResourceMismatchError do
        songs.store_result({
          :response => Net::HTTPResponse.new("1.1", 200, "OK"),
          :code => 200,
          :attrs => {
          "total" => 3,
          "entries" => [
            {"id" => "10", "album" => "10", "title" => "A", "lyrics" => "AA", "artist" => "S1"},
            {"id" => "11", "album" => "10", "title" => "B", "lyrics" => "BB", "artist" => "S1"}
          ]}})
      end
    end

    def test_hash_wrapped_collection_success
      fans = Fans.new()

      fans.store_result({
        :response => Net::HTTPResponse.new("1.1", 200, "OK"),
        :code => 200,
        :attrs => {
          "total" => "20000000",
          "page" => 1020,
          "page_size" => 3,
          "next" => "/v1/fans/?after=3302&page_size=3",
          "prev" => "/v1/fans/?before=4901&page_size=3",
          "fans" => [
            {"id" => "4901", "name" => "Sandy"},
            {"id" => "1010", "name" => "Jodie"},
            {"id" => "3302", "name" => "Barry"}
          ]}})

      # Verify that a collection returns instances of items class
      fans.items.each do |fan|
        assert_equal(Fan, fan.class)
      end

      # Using instance accessors
      names = fans.items.collect {|fan| fan.name}
      assert_equal(["Sandy", "Jodie", "Barry"], names)
    end

    def test_hash_wrapped_collection_failure
      fans = Fans.new()
      assert_raise Qumulo::Rest::ResourceMismatchError do
        fans.store_result({
          :response => Net::HTTPResponse.new("1.1", 200, "OK"),
          :code => 200,
          :attrs => {
            "total" => "20000000",
            "page" => 1020,
            "page_size" => 3,
            "next" => "/v1/fans/?after=3302&page_size=3",
            "prev" => "/v1/fans/?before=4901&page_size=3",
            "entries" => [ # ERROR! key should have been "fans"
              {"id" => "4901", "name" => "Sandy"},
              {"id" => "1010", "name" => "Jodie"},
              {"id" => "3302", "name" => "Barry"}
            ]}})
      end
    end

    def test_collection_url
      fans = Fans.new()
      assert_equal("/v1/fans/", fans.resolved_path)

      songs = Songs.new(:album => "10")
      assert_equal("/v1/albums/10/songs/", songs.resolved_path)
    end

    def test_singleton_collection_post
      # Post using instance method
      FakeHttp.set_fake_response(:post, "/v1/fans/", {
          :code => 203,
          :attrs => {"id" => "13", "name" => "Dmitri"}})
      fans = Fans.new
      new_fan = fans.post(:name => "Dmitri")
      assert_equal("13", new_fan.id)
      assert_equal("Dmitri", new_fan.name)

      # Post using class method
      FakeHttp.set_fake_response(:post, "/v1/fans/", {
          :code => 203,
          :attrs => {"id" => "12", "name" => "Igor"}})
      new_fan = Fans.post(:name => "Igor")
      assert_equal("12", new_fan.id)
      assert_equal("Igor", new_fan.name)

      # Post using class method, and an instance of item class
      FakeHttp.set_fake_response(:post, "/v1/fans/", {
          :code => 203,
          :attrs => {"id" => "11", "name" => "Elsa"}})
      elsa = Fan.new(:name => "Elsa")
      new_fan = Fans.post(elsa)
      assert_equal("11", new_fan.id)
      assert_equal("Elsa", new_fan.name)
    end

    def test_non_singleton_collection_post
      # Post using instance method
      FakeHttp.set_fake_response(:post, "/v1/albums/10/songs/", {
          :code => 203,
          :attrs => {"id" => "100", "album" => "10",
                     "title" => "Sea", "lyrics" => "great",
                     "artist" => "boozy"}})
      songs = Songs.new(:album => "10")
      new_song = songs.post("album" => "10", "title" => "Sea",
                            "lyrics" => "great", "artist" => "boozy")
      assert_equal("100", new_song.id)
      assert_equal("10", new_song.album)
      assert_equal("Sea", new_song.title)
      assert_equal("great", new_song.lyrics)
      assert_equal("boozy", new_song.artist)

      # Post using instance method and item class instance
      FakeHttp.set_fake_response(:post, "/v1/albums/10/songs/", {
          :code => 203,
          :attrs => {"id" => "120", "album" => "10",
                     "title" => "Sky", "lyrics" => "clear",
                     "artist" => "gogo"}})
      songs = Songs.new(:album => "10")
      sky = Song.new("album" => "10", "title" => "Sky",
                     "lyrics" => "clear", "artist" => "gogo")
      new_song = songs.post(sky)
      assert_equal("120", new_song.id)
      assert_equal("10", new_song.album)
      assert_equal("Sky", new_song.title)
      assert_equal("clear", new_song.lyrics)
      assert_equal("gogo", new_song.artist)

      # You cannot post via class method on this collection class.
      # This is because the collection class inherently belongs to another
      # REST resource Album, and we cannot resolve the URI (/v1/albums/:album/songs/)
      # unless you have a value for :album
      FakeHttp.set_fake_response(:post, "/v1/albums/10/songs/", {
          :code => 203,
          :attrs => {"id" => "100", "album" => "10",
                     "title" => "Sea", "lyrics" => "great",
                     "artist" => "boozy"}})
      assert_raise NameError do
          new_song = Songs.post("album" => "10", "title" => "Sea",
                                "lyrics" => "great", "artist" => "boozy")
      end
    end
  end
end

