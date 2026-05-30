# frozen_string_literal: true

module Anypost
  # An immutable view over a decoded JSON response object.
  #
  # Read fields with either method or bracket syntax — both return the same
  # value, and nested objects come back as {Response} instances:
  #
  #   email = client.email.send(...)
  #   email.id          # "email_..."
  #   email[:id]        # same
  #   email["id"]       # same
  #
  # Lists of objects come back as plain Ruby arrays whose object elements are
  # themselves {Response} instances. Call {#to_h} for the raw decoded hash.
  class Response
    # Wrap a decoded JSON value, turning object-shaped hashes into responses.
    def self.wrap(value)
      case value
      when Hash then new(value)
      when Array then value.map { |element| wrap(element) }
      else value
      end
    end

    # @param attributes [Hash] decoded JSON object (string keys)
    def initialize(attributes)
      @attributes = attributes
    end

    def [](key)
      Response.wrap(@attributes[key.to_s])
    end

    def key?(key)
      @attributes.key?(key.to_s)
    end

    # The raw decoded response, with no {Response} wrapping at any depth.
    # @return [Hash]
    def to_h
      @attributes
    end
    alias_method :to_hash, :to_h

    def ==(other)
      other.is_a?(Response) ? to_h == other.to_h : @attributes == other
    end

    def inspect
      "#<Anypost::Response #{@attributes.inspect}>"
    end

    def respond_to_missing?(name, include_private = false)
      @attributes.key?(name.to_s) || super
    end

    def method_missing(name, *args)
      key = name.to_s
      if @attributes.key?(key)
        Response.wrap(@attributes[key])
      else
        super
      end
    end
  end
end
