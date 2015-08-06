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

require "qumulo/rest/base"

module Qumulo::Rest

  # == Class Descriotion
  # All other RESTful collection classes inherit from this class. This class provides a few additonal
  # functionality on top of the regular resource base class, including:
  # * DSL for defining the item of the collection
  # * access methods for getting an array of items
  # *
  #
  class BaseCollection < Base

    # --------------------------------------------------------------------------
    # Class methods
    #
    class << self

      attr_reader :items_field

      # === Description
      # Specify the class of the items in collection.
      #
      # === Parameters
      # item_class:: the class of each item in the collection
      # opts:: Hash object describing additional details
      # opts[:field]:: name of the field (if any) that contains the collection of items.
      #                (see examples section)
      #
      # === Examples
      # A colleciton URL may return a JSON array on GET operation, for example:
      #
      # [
      #   {
      #      "id": "10",
      #      "fname": "John",
      #      "lname": "Smith"
      #   }
      #   {
      #      "id": "12",
      #      "fname": "David",
      #      "lname": "Grant"
      #   },
      #   ...
      # ]
      #
      # In this case, you can simply define the collection as:
      #
      # class PersonCollection
      #   uri_spec "/v1/persons/"
      #   items Person
      # end
      #
      # Some collections may wrap the array with some additional items around it
      # and return a JSON dictionary on GET operation, like this:
      #
      # {
      #   "entries": [
      #     {
      #        "id": "10",
      #        "fname": "John",
      #        "lname": "Smith"
      #     }
      #     {
      #        "id": "12",
      #        "fname": "David",
      #        "lname": "Grant"
      #     },
      #     ...
      #     {
      #        "id": "24",
      #        "fname": "David",
      #        "lname": "Grant"
      #     },
      #   ],
      #   "total": 129983,
      #   "page": 2,
      #   "page_size": 10,
      #   "prev": "/v1/persons/?before=10",
      #   "next": "/v1/persons/?after=24"
      # }
      #
      # Then, you can define the collection as:
      #
      # class PersonCollection
      #   uri_spec "/v1/persons/"
      #   items Person, :field => :entries
      #   field :total, Integer
      #   field :page, Integer
      #   field :page_size, Integer
      #   field :pref, String
      #   field :next, String
      # end
      #
      def items(item_class, opts = {})
        @item_class = item_class
        if opts[:field]
          @items_field = opts[:field]
          # define the field so that getter/setter works
          field opts[:field], array_of(@item_class)
        end
      end

      # === Description
      # Return the item class for given collection class.
      #
      def item_class
        @item_class || self.superclass.get_item_class
      end

      # === Description
      # Perform POST request to create the resource on the server-side.
      #
      # === Parameters
      # attrs:: attributes to pass to post
      # request_opts:: Hash object to feed to RequstOptions constructor.
      #
      # === Returns
      # Returns an instance object of relevant resource class representing
      # the new resource
      #
      # === Raises
      # RequestFailed if error
      #
      def post(attrs = {}, request_opts = {})
        # assumes that the current collection is a singleton, and the uri_spec
        # has no components that require resolution.
        if @uri_spec.include?(":")
          UriError.new("Singleton collection expected, " +
                       "but collection URI requires resolution: #{@uri_spec}")
        end

        self.new().post(attrs, request_opts)
      end

    end

    # --------------------------------------------------------------------------
    # Intance methods
    #

    # === Description
    # Get an array of item object from the collection, if the item has been
    # retrieved.  Otherwise, raises NoData exception.
    #
    # === Returns
    # Array
    def items
      if @items.nil?
        raise NoData.new("No data has been retrieved yet.", self)
      else
        @items.collect do |hsh|
          item = self.class.item_class.new
          item.store_result(:attrs => hsh)
          item
        end
      end
    end

    # === Description
    # Store the result of an HTTP request.  This is a collection, so, in addition to
    # what Base class stores, it needs to store the result into @items.
    #
    # === Parameters
    # result:: Hash object of form:
    # {
    #   :response => <Net::HTTPResponse object resulting from Http request>,
    #   :attrs => <Array or Hash object for collection> or <nil> if request failed,
    #   :error => <Hash object for error structure> or <nil> if request success
    # }
    #
    # === Returns
    # self
    #
    def store_result(result)
      super
      if not self.class.item_class
          raise ResourceMismatchError.new(
            "A collection class #{self.class.name} has no item class defined.")
      end
      case @attrs
      when Array
        @items = @attrs
      when Hash
        if not self.class.items_field
          raise ResourceMismatchError.new(
            "Received a response dictionary, but collection class has no items_field.")
        end
        if not @attrs.key?(self.class.items_field.to_s)
          raise ResourceMismatchError.new(
            "The response does not have expected items_field: #{self.class.items_field}",
            self)
        end
        @items = @attrs[self.class.items_field.to_s]
        if not @items.is_a?(Array)
          raise ResourceMismatchError.new(
            "Expected Array but got #{@items.inspect} for items_field: #{self.class.items_field}",
            self)
        end
      end
      self
    end

    # === Description
    # Create a new member of the collection via POST request.
    #
    # === Parameters
    # member:: instance of items class for the collection -or-
    #          Hash object that contains the attributes of the new member
    #
    # === Returns
    # instance of items class corresponding to the new entry
    #
    def post(payload, request_opts={})
      if payload.is_a?(Hash)
        payload = self.class.item_class.new(payload) # apply data type conversion
      end
      qs = payload.query_string_params
      payload = payload.as_hash
      response = http(request_opts).post(resolved_path + qs, payload)
      new_item = self.class.item_class.new
      new_item.store_result(response)
      new_item
    end

  end

end
