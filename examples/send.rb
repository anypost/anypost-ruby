# frozen_string_literal: true

require "anypost"

# Reads ANYPOST_API_KEY from the environment. Pass the key explicitly with
# Anypost::Client.new("ap_...") if you prefer.
client = Anypost::Client.new

begin
  email = client.email.send(
    from: "Acme <you@yourdomain.com>",
    to: ["someone@example.com"],
    subject: "Hello from Anypost",
    html: "<p>It worked.</p>"
  )
  puts "Queued #{email.id}"
rescue Anypost::Error => e
  warn "Send failed: #{e.type} — #{e.message}"
  exit 1
end
