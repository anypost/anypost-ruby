# frozen_string_literal: true

require "spec_helper"

RSpec.describe Anypost::Resources::Email do
  let(:client) { build_client }

  it "posts to /email and parses the response" do
    server.stub(:post, "/v1/email", status: 202, body: {id: "email_abc", created_at: "2026-05-29T00:00:00Z"})

    email = client.email.send(
      from: "Acme <you@yourdomain.com>",
      to: ["someone@example.com"],
      subject: "Hello",
      html: "<p>It worked.</p>"
    )

    request = server.last_request
    expect(request.method).to eq(:post)
    expect(request.path).to eq("/v1/email")
    expect(email.id).to eq("email_abc")
    expect(email[:created_at]).to eq("2026-05-29T00:00:00Z")

    body = request.json_body
    expect(body["from"]).to eq("Acme <you@yourdomain.com>")
    expect(body["to"]).to eq(["someone@example.com"])
  end

  it "auto-generates an idempotency key" do
    server.stub(:post, "/v1/email", status: 202, body: {id: "email_1", created_at: "now"})
    client.email.send(from: "a@b.com", to: ["c@d.com"], text: "x")

    key = server.last_request.header("Idempotency-Key")
    expect(key).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
  end

  it "respects an explicit idempotency key" do
    server.stub(:post, "/v1/email", status: 202, body: {id: "email_1", created_at: "now"})
    client.email.send({from: "a@b.com", to: ["c@d.com"], text: "x"}, "my-key-123")

    expect(server.last_request.header("Idempotency-Key")).to eq("my-key-123")
  end

  it "sets no idempotency key when retries are disabled" do
    server.stub(:post, "/v1/email", status: 202, body: {id: "email_1", created_at: "now"})
    build_client("ap_test", max_retries: 0).email.send(from: "a@b.com", to: ["c@d.com"], text: "x")

    expect(server.last_request.header("Idempotency-Key")).to be_nil
  end

  it "base64-encodes raw attachment content" do
    server.stub(:post, "/v1/email", status: 202, body: {id: "email_1", created_at: "now"})
    client.email.send(
      from: "a@b.com",
      to: ["c@d.com"],
      subject: "With file",
      text: "see attached",
      attachments: [{filename: "hello.txt", content: "hello world"}]
    )

    body = server.last_request.json_body
    expect(body["attachments"][0]["content"]).to eq(["hello world"].pack("m0"))
    expect(body["attachments"][0]["filename"]).to eq("hello.txt")
  end

  it "does not raise on a 207 batch and exposes each entry" do
    server.stub(:post, "/v1/email/batch", status: 207, body: {
      summary: {total: 2, queued: 1, failed: 1},
      data: [
        {status: "queued", index: 0, id: "email_1", created_at: "now"},
        {status: "failed", index: 1, error: {type: "validation_error", message: "bad"}}
      ]
    })

    batch = client.email.send_batch(emails: [
      {from: "a@b.com", to: ["ok@example.com"], text: "x"},
      {from: "a@b.com", to: ["bad"], text: "x"}
    ])

    expect(server.last_request.path).to eq("/v1/email/batch")
    expect(batch.summary.queued).to eq(1)
    expect(batch.data.length).to eq(2)
    expect(batch.data[1].status).to eq("failed")
    expect(batch.data[1].error.type).to eq("validation_error")
  end

  it "encodes attachments in batch defaults and emails" do
    server.stub(:post, "/v1/email/batch", status: 202, body: {summary: {}, data: []})
    client.email.send_batch(
      defaults: {attachments: [{filename: "d.txt", content: "default-bytes"}]},
      emails: [
        {from: "a@b.com", to: ["c@d.com"], text: "x",
         attachments: [{filename: "e.txt", content: "email-bytes"}]}
      ]
    )

    body = server.last_request.json_body
    expect(body["defaults"]["attachments"][0]["content"]).to eq(["default-bytes"].pack("m0"))
    expect(body["emails"][0]["attachments"][0]["content"]).to eq(["email-bytes"].pack("m0"))
  end
end
