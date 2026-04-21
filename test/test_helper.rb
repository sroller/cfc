# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  # Exclude test/ and exe/ directories from coverage calculation
  add_filter "/test/"
  add_filter "/exe/"

  # Coverage tracking for source files only (lib/)
  minimum_coverage 90
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "cfc"

require "minitest/autorun"

class Minitest::Test
  def capture_io
    require "stringio"
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    "#{$stdout.string}#{$stderr.string}"
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end
end
