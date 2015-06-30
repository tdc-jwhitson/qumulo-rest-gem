require "test/unit"
require "test_env"
require "date"
require "net/http"

require "qumulo/rest/exception"
require "qumulo/rest/base"
require "qumulo/rest/base_collection"

module Qumulo::Rest

  class Book < Qumulo::Rest::Base
    field :title, String
    field :author, String
    field :num_pages, Integer
  end

  class Address < Qumulo::Rest::Base
    field :street, String
    field :city, String
    field :state, String
    field :zip, String
  end

  class Library < Qumulo::Rest::Base
    field :name, String
    field :address, Address
    field :best_sellers, array_of(Book)
    field :on_hold, array_of(Book)
  end

  class BaseTest < Test::Unit::TestCase
    include TestEnv

    def setup
      set_up_fake_connection
    end

    def teardown
      tear_down_fake_connection
    end

    def test_creating_complex_object
      book1 = Book.new(:title => "The Girl on the Train",
                       :author => "Paula Hawkins",
                       :num_pages => 336)
      book2 = Book.new(:title => "The Wright Brothers",
                       :author => "David McCullough",
                       :num_pages => 336)
      book3 = Book.new(:title => "The Martian",
                       :author => "Andy Weir",
                       :num_pages => 387)
      book4 = Book.new(:title => "Sharp Objects",
                       :author => "Gillian Flynn",
                       :num_pages => 254)
      address = Address.new(
                       :street => "1002 Elm Street",
                       :city => "Pleasantville",
                       :state => "Oklahoma",
                       :zip => "74079")

      # Successfully setting fields via accessors
      library = Library.new()
      library.name = "Ridgewood Library"
      library.address = address
      library.best_sellers = [book1, book2, book3]
      library.on_hold = [book3, book4]

      # Verify the expected json form
      assert_equal({
        "name"=>"Ridgewood Library",
        "address"=>{"street"=>"1002 Elm Street",
                    "city"=>"Pleasantville", "state"=>"Oklahoma",
                    "zip"=>"74079"},
        "best_sellers"=>[
          { "title"=>"The Girl on the Train", "author"=>"Paula Hawkins", "num_pages"=>336 },
          { "title"=>"The Wright Brothers",  "author"=>"David McCullough", "num_pages"=>336 },
          { "title"=>"The Martian", "author"=>"Andy Weir", "num_pages"=>387}
          ],
        "on_hold"=>[
          { "title"=>"The Martian", "author"=>"Andy Weir", "num_pages"=>387 },
          { "title"=>"Sharp Objects", "author"=>"Gillian Flynn", "num_pages"=>254}
          ]
        },
        library.as_hash)
    end

    def test_receiving_complex_object

      # Simulate receiving JSON response from server
      library = Library.new()
      library.store_result(
        :response => Net::HTTPResponse.new("1.1", 200, "OK"),
        :code => 200,
        :attrs => {
          "name"=>"Ridgewood Library",
          "address"=>{"street"=>"1002 Elm Street",
                      "city"=>"Pleasantville", "state"=>"Oklahoma",
                      "zip"=>"74079"},
          "best_sellers"=>[
            { "title"=>"The Girl on the Train", "author"=>"Paula Hawkins", "num_pages"=>336 },
            { "title"=>"The Wright Brothers",  "author"=>"David McCullough", "num_pages"=>336 },
            { "title"=>"The Martian", "author"=>"Andy Weir", "num_pages"=>387}
            ],
          "on_hold"=>[
            { "title"=>"The Martian", "author"=>"Andy Weir", "num_pages"=>387 },
            { "title"=>"Sharp Objects", "author"=>"Gillian Flynn", "num_pages"=>254}
            ]
          })

      # Verify name and address
      assert_equal("Ridgewood Library", library.name)
      assert_instance_of(Address, library.address)
      assert_equal("1002 Elm Street", library.address.street)
      assert_equal("Pleasantville", library.address.city)
      assert_equal("Oklahoma", library.address.state)
      assert_equal("74079", library.address.zip)

      # Verify arrays that contain books
      library.best_sellers.each do |book|
        assert_instance_of(Book, book)
      end

    end

    def test_invalid_setter_invocation
      library = Library.new()

      # Cannot assign a field with unexpected data type, in this case Address
      # is expected, but Hash is being given.
      assert_raise DataTypeError do
        library.address = {"street"=>"1002 Elm Street",
                           "city"=>"Pleasantville", "state"=>"Oklahoma",
                           "zip"=>"74079"}
      end

      # Cannot assign an array with the wrong element type; in this case, we need
      # an array of Book instances, but an array of Hash instances are given.
      assert_raise DataTypeError do
        library.best_sellers = [
            { "title"=>"The Girl on the Train", "author"=>"Paula Hawkins", "num_pages"=>336 },
            { "title"=>"The Wright Brothers",  "author"=>"David McCullough", "num_pages"=>336 }
        ]
      end
    end

  end
end

