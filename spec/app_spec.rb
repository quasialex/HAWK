# frozen_string_literal: true
require "spec_helper"

RSpec.describe "HAWK app" do
  it "serves health" do
    get "/health"
    expect(last_response.status).to eq 200
    body = JSON.parse(last_response.body)
    expect(body["ok"]).to eq(true)
  end

  it "serves index" do
    get "/"
    expect(last_response).to be_ok
  end

  it "serves tty" do
    get "/tty"
    expect(last_response).to be_ok
  end
end
