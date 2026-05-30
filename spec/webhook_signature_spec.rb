# frozen_string_literal: true

require "spec_helper"

RSpec.describe Anypost::WebhookSignature do
  secret = "whsec_test_secret"
  payload = '{"batch_id":"wb_1","timestamp":1000,"events":[{"id":"evt_1","type":"email.delivered"}]}'

  def sign(payload, timestamp, secret)
    OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
  end

  it "accepts a valid signature" do
    header = "t=1000,v1=#{sign(payload, 1000, secret)}"
    expect { described_class.verify(payload, header, secret, now: 1005) }.not_to raise_error
  end

  it "rejects a tampered payload" do
    header = "t=1000,v1=#{sign(payload, 1000, secret)}"
    expect { described_class.verify('{"batch_id":"tampered"}', header, secret, now: 1000) }
      .to raise_error(Anypost::WebhookVerificationError) { |e| expect(e.reason).to eq(:no_match) }
  end

  it "passes when any v1 matches during rotation" do
    good = sign(payload, 1000, secret)
    header = "t=1000,v1=#{"0" * 64},v1=#{good}"
    expect { described_class.verify(payload, header, secret, now: 1000) }.not_to raise_error
  end

  it "rejects a stale timestamp" do
    header = "t=1000,v1=#{sign(payload, 1000, secret)}"
    expect { described_class.verify(payload, header, secret, tolerance_seconds: 300, now: 1301) }
      .to raise_error(Anypost::WebhookVerificationError) { |e| expect(e.reason).to eq(:timestamp_out_of_tolerance) }
  end

  it "disables the freshness check when tolerance is 0" do
    header = "t=1000,v1=#{sign(payload, 1000, secret)}"
    expect { described_class.verify(payload, header, secret, tolerance_seconds: 0, now: 999_999) }.not_to raise_error
  end

  it "rejects a malformed header" do
    expect { described_class.verify(payload, "", secret) }
      .to raise_error(Anypost::WebhookVerificationError) { |e| expect(e.reason).to eq(:malformed_header) }
  end

  it "rejects a header without a timestamp" do
    expect { described_class.verify(payload, "v1=abc", secret) }
      .to raise_error(Anypost::WebhookVerificationError) { |e| expect(e.reason).to eq(:no_timestamp) }
  end

  it "rejects a header without a signature" do
    expect { described_class.verify(payload, "t=1000", secret) }
      .to raise_error(Anypost::WebhookVerificationError) { |e| expect(e.reason).to eq(:no_signatures) }
  end

  it "unwraps the parsed delivery" do
    header = "t=1000,v1=#{sign(payload, 1000, secret)}"
    delivery = described_class.unwrap(payload, header, secret, now: 1000)

    expect(delivery).to be_a(Anypost::Response)
    expect(delivery.batch_id).to eq("wb_1")
    expect(delivery.events[0].id).to eq("evt_1")
  end
end
