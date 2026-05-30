# frozen_string_literal: true

require "spec_helper"

RSpec.describe "resources" do
  let(:client) { build_client }

  it "reads identity from whoami" do
    server.stub(:get, "/v1/whoami", body: {
      team: {id: "team_1", name: "Acme"}, api_key: {id: "key_1", permissions: "full"}
    })

    me = client.whoami

    expect(server.last_request.path).to eq("/v1/whoami")
    expect(me.team.name).to eq("Acme")
    expect(me.api_key.permissions).to eq("full")
  end

  it "covers the domains CRUD + verify request shapes" do
    server.stub(:post, "/v1/domains", body: {id: "dom_1"})
    server.stub(:get, "/v1/domains/dom_1", body: {id: "dom_1"})
    server.stub(:patch, "/v1/domains/dom_1", body: {id: "dom_1"})
    server.stub(:delete, "/v1/domains/dom_1", status: 204, body: "")
    server.stub(:post, "/v1/domains/dom_1/verify", body: {id: "dom_1", status: "pending"})

    client.domains.create(name: "mail.acme.com")
    expect(server.last_request.method).to eq(:post)
    expect(server.last_request.json_body["name"]).to eq("mail.acme.com")

    client.domains.get("dom_1")
    expect(server.last_request.method).to eq(:get)

    client.domains.update("dom_1", tracking: {opens: true})
    expect(server.last_request.method).to eq(:patch)

    expect(client.domains.delete("dom_1")).to be_nil
    expect(server.last_request.method).to eq(:delete)

    domain = client.domains.verify("dom_1")
    expect(server.last_request.path).to eq("/v1/domains/dom_1/verify")
    expect(domain.status).to eq("pending")
  end

  it "covers the template draft and publish endpoints" do
    server.stub(:get, "/v1/templates/tpl_1/draft", body: {template_id: "tpl_1"})
    server.stub(:patch, "/v1/templates/tpl_1/draft", body: {template_id: "tpl_1"})
    server.stub(:delete, "/v1/templates/tpl_1/draft", status: 204, body: "")
    server.stub(:post, "/v1/templates/tpl_1/publish", body: {id: "tpl_1", published: true})
    server.stub(:post, "/v1/templates/tpl_1/duplicate", body: {id: "tpl_2"})

    client.templates.get_draft("tpl_1")
    expect(server.last_request.path).to eq("/v1/templates/tpl_1/draft")

    client.templates.update_draft("tpl_1", subject: "Hi {{name}}")
    expect(server.last_request.method).to eq(:patch)
    expect(server.last_request.json_body["subject"]).to eq("Hi {{name}}")

    client.templates.delete_draft("tpl_1")
    expect(server.last_request.method).to eq(:delete)

    client.templates.publish("tpl_1")
    expect(server.last_request.path).to eq("/v1/templates/tpl_1/publish")

    client.templates.duplicate("tpl_1", name: "Copy")
    expect(server.last_request.path).to eq("/v1/templates/tpl_1/duplicate")
    expect(server.last_request.json_body["name"]).to eq("Copy")
  end

  it "tests and rotates a webhook secret" do
    server.stub(:post, "/v1/webhooks/wh_1/test", body: {delivered: true, status_code: 200})
    server.stub(:post, "/v1/webhooks/wh_1/rotate-secret", body: {id: "wh_1", signing_secret: "whsec_new"})

    result = client.webhooks.test("wh_1")
    expect(server.last_request.path).to eq("/v1/webhooks/wh_1/test")
    expect(result.delivered).to be(true)

    rotated = client.webhooks.rotate_secret("wh_1")
    expect(server.last_request.path).to eq("/v1/webhooks/wh_1/rotate-secret")
    expect(rotated.signing_secret).to eq("whsec_new")
  end

  it "returns the secret on api key create" do
    server.stub(:post, "/v1/api-keys", body: {id: "key_1", key: "ap_secret"})

    key = client.api_keys.create(name: "CI", permissions: "send_only")
    expect(server.last_request.path).to eq("/v1/api-keys")
    expect(key.key).to eq("ap_secret")
  end

  it "percent-encodes email and topic in the suppression path" do
    server.stub(:get, "/v1/suppressions/a%2Bb%40c.com/%2A", body: {email: "a+b@c.com", topic: "*"})
    server.stub(:delete, "/v1/suppressions/a%2Bb%40c.com/%2A", status: 204, body: "")

    client.suppressions.get("a+b@c.com", "*")
    expect(server.last_request.path).to include("%2A")
    expect(server.last_request.path).to include("%40")

    client.suppressions.delete("a+b@c.com", "*")
    expect(server.last_request.method).to eq(:delete)
  end

  it "lists every suppression for an email" do
    server.stub(:get, "/v1/suppressions/a%40b.com", body: {
      data: [{email: "a@b.com", topic: "*"}, {email: "a@b.com", topic: "news"}]
    })

    rows = client.suppressions.list_for_email("a@b.com")
    expect(rows.length).to eq(2)
    expect(rows[1].topic).to eq("news")
  end

  it "joins event tags as csv" do
    server.stub(:get, "/v1/events", body: {data: [], has_more: false, next_cursor: nil})

    client.events.list(event_type: "email.delivered", tags: %w[welcome onboarding])

    expect(server.last_request.query["event_type"]).to eq("email.delivered")
    expect(server.last_request.query["tags"]).to eq("welcome,onboarding")
  end
end
