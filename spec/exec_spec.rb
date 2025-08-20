# frozen_string_literal: true
require "spec_helper"

RSpec.describe Exec do
  it "runs a simple command and writes a log" do
    log = Exec.run("echo hello", name: "test-echo")
    expect(File).to exist(log)
    expect(File.read(log)).to include("hello")
  end
end
