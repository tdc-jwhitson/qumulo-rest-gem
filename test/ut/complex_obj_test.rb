require "minitest/autorun"
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

  class TypedArrayTest < Minitest::Test
    include TestEnv

    def setup
      @book_array = Class.new(TypedArray)
      @book_array.set_element_type(Book)
      @book1 = Book.new(:title => "A", :author => "AA", :num_pages => 200)
      @book2 = Book.new(:title => "B", :author => "BB", :num_pages => 300)
      @books = @book_array.new([ @book1, @book2 ])
    end

    def test_constructor
      assert_equal([
          { "title"=>"A", "author"=>"AA", "num_pages"=>200 },
          { "title"=>"B", "author"=>"BB", "num_pages"=>300 }
      ], @books.payload)

      books2 = @book_array.new
      assert_equal([], books2.payload)
    end

    def test_constructor_error
      assert_raises DataTypeError do
        @book_array.new([
          Book.new(:title => "A", :author => "AA", :num_pages => 200),
          Address.new(:street => "A", :city => "B", :state => "WA", :zip => "11111")
          ])
      end
    end

    def test_forwarded_methods
      assert_equal(2, @books.length)
      @books.delete_at(1)
      assert_equal([ @book1.as_hash ], @books.payload)
      assert_equal(1, @books.length)
    end

    def test_equality
      # Re-create a wholy new TypedArray object with the same content but different objects
      books2 = @book_array.new([
                 Book.new(:title => "A", :author => "AA", :num_pages => 200),
                 Book.new(:title => "B", :author => "BB", :num_pages => 300)
               ])
      assert_equal(@books, books2)
    end

    def test_each
      @books.each do |elt|
        elt.is_a?(Book)
        elt.title == "A" or elt.title == "B"
      end
    end

    def test_enumerable
      # select
      selected = @books.select { |elt| elt.title == "A" }
      assert_equal([ @book1 ], selected)

      # reduce
      reduced = @books.reduce(0) { |memo, elt| memo += elt.num_pages }
      assert_equal(500, reduced)
    end

    def test_subscript_reference
      # Get
      assert_equal(@book1, @books[0])
      assert_equal(@book2, @books[1])

      # Set
      @books[0].author = "AAA"
      assert_equal("AAA", @book1.author) # Verify that reference is maintained

      # Verify payload
      assert_equal({"title"=>"A", "author" => "AAA", "num_pages" => 200},
        @books[0].as_hash)
      assert_equal([
          { "title"=>"A", "author"=>"AAA", "num_pages"=>200 },
          { "title"=>"B", "author"=>"BB", "num_pages"=>300 }
        ], @books.payload)
    end

    def test_append_first_last
      @book3 = Book.new(:title => "C", :author => "AA", :num_pages => 400)
      @books << @book3
      assert_equal(3, @books.length)
      assert_equal(@book1, @books.first)
      assert_equal(@book3, @books.last)
    end

    def test_insert
      @book3 = Book.new(:title => "C", :author => "AA", :num_pages => 400)
      @books.insert(0, @book3)
      assert_equal(3, @books.length)
      assert_equal(@book3, @books.first)
      assert_equal(@book2, @books.last)
    end

    def test_delete_if
      @books.delete_if do |elt|
        elt.author == "AA"
      end
      assert_equal(1, @books.length)
      assert_equal(@book2, @books[0])
    end

  end

  class BaseTest < Minitest::Test
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
      assert_raises DataTypeError do
        library.address = {"street"=>"1002 Elm Street",
                           "city"=>"Pleasantville", "state"=>"Oklahoma",
                           "zip"=>"74079"}
      end

      # Cannot assign an array with the wrong element type; in this case, we need
      # an array of Book instances, but an array of Hash instances are given.
      assert_raises DataTypeError do
        library.best_sellers = [
            { "title"=>"The Girl on the Train", "author"=>"Paula Hawkins", "num_pages"=>336 },
            { "title"=>"The Wright Brothers",  "author"=>"David McCullough", "num_pages"=>336 }
        ]
      end
    end
  end

end

