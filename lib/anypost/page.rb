# frozen_string_literal: true

module Anypost
  # One page of a list result.
  #
  # Mirrors the wire envelope (`data`, `has_more`, `next_cursor`) and is
  # enumerable: iterating walks every remaining page automatically, re-fetching
  # with `after = next_cursor`.
  #
  #   page = client.domains.list           # one page
  #   page.data                            # just this page's items
  #
  #   client.domains.list.each do |domain| # every domain, across all pages
  #     puts domain.name
  #   end
  class Page
    include Enumerable

    # @return [Array<Response>] the items on this page
    attr_reader :data
    # @return [Boolean]
    attr_reader :has_more
    # @return [String, nil]
    attr_reader :next_cursor

    # @param response [Hash] the decoded page envelope
    # @yieldparam cursor [String] fetches and returns the next {Page}
    def initialize(response, &fetch_next)
      raw = response.is_a?(Hash) ? response : {}
      @data = (raw["data"] || []).map { |item| Response.wrap(item) }
      @has_more = raw["has_more"] || false
      cursor = raw["next_cursor"]
      @next_cursor = cursor.is_a?(String) ? cursor : nil
      @fetch_next = fetch_next
    end

    # Fetch the next page, or nil when there are no more.
    # @return [Page, nil]
    def next_page
      return nil unless @has_more && @next_cursor

      @fetch_next.call(@next_cursor)
    end

    def each
      return enum_for(:each) unless block_given?

      page = self
      while page
        page.data.each { |item| yield item }
        page = page.next_page
      end
    end
  end
end
