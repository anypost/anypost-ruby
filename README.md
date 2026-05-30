# Anypost Ruby SDK

The official Ruby gem for the [Anypost](https://anypost.com) email API.

Requires Ruby 3.2+. Built on [Faraday](https://github.com/lostisland/faraday).

## Install

```bash
gem install anypost
```

Or add it to your Gemfile:

```ruby
gem "anypost"
```

## Quickstart

```ruby
require "anypost"

client = Anypost::Client.new("ap_your_api_key")

email = client.email.send(
  from: "Acme <you@yourdomain.com>",
  to: ["someone@example.com"],
  subject: "Hello from Anypost",
  html: "<p>It worked.</p>"
)

puts email.id
```

The constructor also reads `ANYPOST_API_KEY` from the environment:

```ruby
client = Anypost::Client.new
```

Keep the key server-side. It is a bearer credential; never ship it to a browser or mobile app.

Request bodies are plain hashes with symbol keys that match the API one-to-one. Responses come back as `Anypost::Response` objects: read fields with either method or bracket syntax (`email.id` or `email[:id]`), and nested objects are themselves responses. Call `email.to_h` for the raw decoded hash.

## Sending

One of `text`, `html`, or `template_id` is required. All recipients in `to`, `cc`, and `bcc` share one envelope and count against a combined limit of 50.

```ruby
client.email.send(
  from: "Acme <you@yourdomain.com>",
  to: ["a@example.com", "b@example.com"],
  cc: ["team@example.com"],
  reply_to: "support@yourdomain.com",
  subject: "Receipt #4823",
  html: "<p>Thanks for your order.</p>",
  text: "Thanks for your order.",
  tags: ["receipt"]
)
```

Attachment `content` is the raw file bytes — pass what `File.binread` returns and the SDK base64-encodes it. Do not pre-encode it. The request body is capped at 5 MB.

```ruby
client.email.send(
  from: "you@yourdomain.com",
  to: ["someone@example.com"],
  subject: "Your report",
  text: "Attached.",
  attachments: [
    {filename: "report.pdf", content: File.binread("report.pdf")}
  ]
)
```

Send with a published template and per-recipient variables:

```ruby
client.email.send(
  from: "you@yourdomain.com",
  to: ["someone@example.com"],
  template_id: "template_018f2c5e-3a40-7a91-9c25-3a0b1d5e6f78",
  variables: {name: "Ada", plan: "pro"}
)
```

## Batch

Send 1 to 100 independent messages in one request. `defaults` fills any field an entry omits.

```ruby
result = client.email.send_batch(
  defaults: {from: "you@yourdomain.com"},
  emails: [
    {to: ["a@example.com"], subject: "Hi A", text: "..."},
    {to: ["b@example.com"], subject: "Hi B", text: "..."}
  ]
)
```

A batch with mixed outcomes returns HTTP `207` and resolves normally. Inspect each entry rather than rescuing an error:

```ruby
result.summary # { total:, queued:, failed: }

result.data.each do |entry|
  if entry.status == "queued"
    puts "#{entry.index} #{entry.id}"
  else
    puts "#{entry.index} #{entry.error.type} #{entry.error.message}"
  end
end
```

## Domains

Manage sending domains under `client.domains`. Add a domain, publish the CNAMEs it returns, then verify.

```ruby
domain = client.domains.create(name: "example.com")

domain.dns_records.each do |record|
  puts "#{record.type} #{record.name} -> #{record.value}"
end
```

`verify` always returns the current domain — a still-`pending` domain does not raise. Read `status` and `verification_failure`, and poll while DNS propagates.

```ruby
checked = client.domains.verify(domain.id)
puts checked.verification_failure.code unless checked.status == "verified"
```

`get`, `update` (tracking config only), and `delete` round out the resource:

```ruby
client.domains.update(domain.id, tracking: {opens_enabled: true, clicks_enabled: true, subdomain: "track"})
client.domains.delete(domain.id)
```

## API keys

Manage keys under `client.api_keys`. The plaintext secret comes back only once, on `create`, as `key`:

```ruby
created = client.api_keys.create(
  name: "Production server",
  permissions: "send_only",
  allowed_domains: ["example.com"]
)
puts created.key # store now; never retrievable again

client.api_keys.update(created.id, name: "Production server", permissions: "full")
client.api_keys.delete(created.id)
```

`get` returns metadata only — `key_prefix`, never the secret. Permission and restriction changes take up to 5 minutes to propagate through the gateway cache.

## Templates

Templates use a draft/published model: edits land in a draft, and `publish` promotes it. A template can't be used for sending until it's published.

```ruby
template = client.templates.create(
  name: "Welcome email",
  kind: "html",
  html: "<h1>Welcome, {{ name }}</h1>"
)

client.templates.update_draft(template.id, subject: "Welcome to Acme", html: "<h1>Welcome, {{ name }}</h1>")
client.templates.publish(template.id)
```

`kind` is `html` or `markdown` and is immutable once set. The plain-text body is always derived server-side. `get_draft`, `delete_draft`, `duplicate`, `get`, `update` (name only), and `delete` round out the resource. Send with a published template via `template_id` (see [Sending](#sending)).

## Suppressions

A suppression blocks sends to an address, scoped to a `topic`. The wildcard `*` blocks every topic; a specific topic (e.g. `marketing`) leaves transactional traffic untouched. Bounces and complaints write `*` automatically.

```ruby
client.suppressions.create(email: "alice@example.com", topic: "marketing", note: "Customer requested removal")

row = client.suppressions.get("alice@example.com", "*")
client.suppressions.delete("alice@example.com", "marketing")
```

`list` accepts `email_contains`, `topic`, `reason`, and `origin` filters. `list_for_email` returns every row for an address across all topics; `delete_for_email` removes them all.

```ruby
client.suppressions.list(reason: "complaint").each do |s|
  puts "#{s.email} #{s.topic} #{s.suppressed_at}"
end
```

## Webhooks

Manage webhook subscriptions under `client.webhooks`. The `signing_secret` comes back only once, on `create`; later reads return only `signing_secret_prefix`.

```ruby
webhook = client.webhooks.create(
  name: "Production events",
  url: "https://hooks.example.com/anypost",
  events: ["email.delivered", "email.bounced", "email.complained"]
)
puts webhook.signing_secret # store now; never retrievable again
```

`update` sets the name, URL, events, and `status` together — set `status` to `"disabled"` to pause delivery, `"active"` to resume. `test` sends one synthetic `webhook.test` event and returns the outcome even when the endpoint fails. `rotate_secret` issues a new secret and keeps the previous one valid for a 24-hour grace window; `get`, `list`, and `delete` round out the resource.

```ruby
result = client.webhooks.test(webhook.id)
puts "#{result.status_code} #{result.error}" unless result.delivered

rotated = client.webhooks.rotate_secret(webhook.id)
```

### Verifying deliveries

`Anypost::WebhookSignature.verify` is a module method — it needs the signing secret, not an API key, so call it in your handler without a client. Pass the **raw** request body (the exact bytes, before JSON parsing), the `Anypost-Signature` header, and the secret. It returns on success and raises `Anypost::WebhookVerificationError` otherwise. `Anypost::WebhookSignature.unwrap` does the same and returns the parsed delivery as a `Response`.

```ruby
begin
  delivery = Anypost::WebhookSignature.unwrap(raw_body, signature_header, secret)
  delivery.events.each do |event|
    # event.type, event.data.email_id, ...
  end
rescue Anypost::WebhookVerificationError => e
  # e.reason: :no_match | :timestamp_out_of_tolerance | ...
  halt 400
end
```

Reach for `verify` when something else has already parsed the body. Keep the raw bytes for the verify step, then use your parsed object once it passes — a Rack-style handler:

```ruby
post "/anypost" do
  raw = request.body.read
  begin
    Anypost::WebhookSignature.verify(raw, request.env["HTTP_ANYPOST_SIGNATURE"], secret)
  rescue Anypost::WebhookVerificationError
    halt 400
  end

  JSON.parse(raw)["events"].each { |event| handle(event) }
  status 204
end
```

Deliveries older than five minutes are rejected by default to bound replay; pass `tolerance_seconds:` to widen, narrow, or disable (`0`) that check. During a secret rotation the header carries a `v1=` component per active secret, and a match on any one passes — so deliveries keep verifying while you redeploy.

## Events

`client.events.list` pages the team's event stream, newest-first. The window defaults to the last 24 hours and is clamped to your plan's retention. Events are read-only and not addressable by id — there is no `get`.

```ruby
client.events.list(event_type: "email.bounced").each do |event|
  puts "#{event.occurred_at} #{event.recipient} #{event.bounce_classification}"
end
```

Filter by `start`, `end`, `event_type`, `recipient`, `email_id`, `message_id`, `domain`, `topic`, `campaign`, `template_id`, and `tags`. All filters are exact-match, except `tags`, which takes an array and matches an event carrying *any* of the given tags. A filter value that matches no row returns an empty page. This is also how you backfill the gap after a webhook endpoint was disabled — page the events that occurred during the outage once it's healthy.

```ruby
# Events tagged "onboarding" OR "welcome", that also bounced.
page = client.events.list(tags: ["onboarding", "welcome"], event_type: "email.bounced")
```

## Pagination

List endpoints return a `Page`. Read one page directly, or iterate it to walk every page — the client fetches each one as needed.

```ruby
page = client.domains.list(limit: 50)
page.data        # this page's items
page.has_more    # whether another page exists
page.next_cursor # pass as :after to fetch it yourself

client.domains.list.each do |domain|
  puts domain.name # every domain, across all pages
end
```

A `Page` is `Enumerable`, so `map`, `select`, `find`, and friends all walk every page.

## Errors

A failed request raises an `Anypost::Error` subclass. Branch on `error.type`, the stable machine-readable code, not on the HTTP status.

```ruby
begin
  client.email.send(message)
rescue Anypost::ValidationError => e
  e.errors # {"from" => ["The from field is required."]}
rescue Anypost::RateLimitError => e
  e.retry_after # seconds, or nil
rescue Anypost::Error => e
  "#{e.type} #{e.status} #{e.message}"
end
```

| Class | `type` | Status |
|---|---|---|
| `ValidationError` | `validation_error` | `400`, `422` |
| `AuthenticationError` | `authentication_error` | `401` |
| `PermissionError` | `permission_error` | `403` |
| `NotFoundError` | `not_found` | `404` |
| `ConflictError` | `idempotency_concurrent`, `webhook_rotation_in_progress` | `409` |
| `IdempotencyMismatchError` | `idempotency_mismatch` | `422` |
| `RateLimitError` | `rate_limit_exceeded` | `429` |
| `PayloadTooLargeError` | `payload_too_large` | `413` |
| `APIError` | `internal_error`, `provisioning_error` | `5xx` |
| `APIConnectionError` | `connection_error` | none |

Every error carries `type`, `status`, `message`, `request_id`, and the parsed `raw` body.

## Retries and idempotency

The client retries `429`, `502`, `503`, and network failures up to `max_retries` times (default 2), with exponential backoff and full jitter. It honors `Retry-After`.

Sends are made safe to retry automatically: when retries are enabled and you do not pass an idempotency key, the client generates one and reuses it across attempts, so a retried send cannot deliver twice. Pass your own key (the second argument) to dedupe across process restarts:

```ruby
client.email.send(message, order_id)
client.email.send_batch(batch, idempotency_key)
```

## Configuration

```ruby
Anypost::Client.new(
  "ap_your_api_key",
  base_url: "https://api.anypost.com/v1",
  timeout: 30,
  max_retries: 2,
  default_headers: {"X-My-Header" => "value"}
)
```

| Option | Default | Description |
|---|---|---|
| `base_url` | `https://api.anypost.com/v1` | API base URL. |
| `timeout` | `30` | Per-request timeout, in seconds. |
| `max_retries` | `2` | Automatic retries for transient failures. |
| `default_headers` | `{}` | Extra headers sent on every request. |
| `connection` | a new one | Bring your own Faraday connection. |

The first argument is the API key (`ap_...`); omit it to read `ANYPOST_API_KEY`. `send` and `send_batch` accept a per-call idempotency key as their second argument.

## License

MIT
