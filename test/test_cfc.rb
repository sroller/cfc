# frozen_string_literal: true

require "test_helper"
require "cfc/downloader"
require "cfc/db"
require "stringio"
require "tmpdir"

class TestCfc < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Cfc::VERSION
  end

  def test_it_does_something_useful
    assert Cfc::VERSION
  end

  # --- valid_date_format? tests ---
  def test_valid_date_format_with_dashes
    assert(Cfc::CLI.valid_date_format?("2026-01-01"))
  end

  def test_valid_date_format_compact
    assert(Cfc::CLI.valid_date_format?("20260101"))
  end

  def test_valid_date_format_with_nil
    refute(Cfc::CLI.valid_date_format?(nil))
  end

  def test_valid_date_format_with_empty
    refute(Cfc::CLI.valid_date_format?(""))
  end

  def test_valid_date_format_with_invalid
    refute(Cfc::CLI.valid_date_format?("2026/01/01"))
    refute(Cfc::CLI.valid_date_format?("01-01-2026"))
    refute(Cfc::CLI.valid_date_format?("2026-1-1"))
    refute(Cfc::CLI.valid_date_format?("2026"))
    refute(Cfc::CLI.valid_date_format?("abc"))
  end
end
