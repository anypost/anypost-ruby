# frozen_string_literal: true

require "spec_helper"

RSpec.describe Anypost::Page do
  let(:client) { build_client }

  it "returns a single page with wrapped items" do
    server.stub(:get, "/v1/domains", body: {
      data: [{id: "dom_1"}, {id: "dom_2"}], has_more: false, next_cursor: nil
    })

    page = client.domains.list

    expect(page.data.length).to eq(2)
    expect(page.data.first).to be_a(Anypost::Response)
    expect(page.data.first.id).to eq("dom_1")
    expect(page.has_more).to be(false)
    expect(page.next_page).to be_nil
  end

  it "iterates across every page" do
    server.stub(:get, "/v1/domains", body: {
      data: [{id: "dom_1"}, {id: "dom_2"}], has_more: true, next_cursor: "cursor_2"
    })
    server.stub(:get, "/v1/domains", body: {
      data: [{id: "dom_3"}], has_more: false, next_cursor: nil
    })

    ids = client.domains.list(limit: 2).map(&:id)

    expect(ids).to eq(%w[dom_1 dom_2 dom_3])
    expect(server.requests.length).to eq(2)
    expect(server.requests[1].query["after"]).to eq("cursor_2")
    expect(server.requests[1].query["limit"]).to eq("2")
  end

  it "omits null query params on the first page" do
    server.stub(:get, "/v1/domains", body: {data: [], has_more: false, next_cursor: nil})

    client.domains.list

    expect(server.last_request.query).to eq({})
  end
end
