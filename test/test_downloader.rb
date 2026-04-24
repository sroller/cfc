# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestDownloader < Minitest::Test
  def setup
    @cache_dir = Cfc::Downloader::CACHE_DIR
    @history_dir = Cfc::Downloader::HISTORY_DIR
    @cache_file = Cfc::Downloader::CACHE_FILE
    @etag_file = Cfc::Downloader::CACHE_ETAG_FILE
    FileUtils.mkdir_p(@cache_dir)
    FileUtils.mkdir_p(@history_dir)
    # Save original files if they exist
    @orig_cache = File.exist?(@cache_file) ? File.read(@cache_file) : nil
    @orig_etag = File.exist?(@etag_file) ? File.read(@etag_file) : nil
    FileUtils.rm_f(@cache_file)
    FileUtils.rm_f(@etag_file)
  end

  def teardown
    # Restore original files
    if @orig_cache
      File.write(@cache_file, @orig_cache)
    else
      FileUtils.rm_f(@cache_file)
    end
    if @orig_etag
      File.write(@etag_file, @orig_etag)
    else
      FileUtils.rm_f(@etag_file)
    end
  end

  def test_parse_csv_line_with_valid_data
    line = "100_001,2036-03-09,Smith,Alice,ON,Toronto,1500,1550,1490,1540"
    result = Cfc::Downloader.parse_csv_line(line)

    assert_equal(100_001, result[:cfc_id])
    refute_nil(result[:expire_date])
    assert_equal("Smith", result[:last_name])
    assert_equal("Alice", result[:first_name])
    assert_equal("ON", result[:province])
    assert_equal("Toronto", result[:city])
  end

  def test_parse_csv_line_with_invalid_data
    assert_nil(Cfc::Downloader.parse_csv_line("100_001,2036-03-09,Smith"))
    assert_nil(Cfc::Downloader.parse_csv_line(""))
    assert_nil(Cfc::Downloader.parse_csv_line(nil))
  end

  def test_parse_int_with_valid_values
    assert_equal(100_001, Cfc::Downloader.parse_int("100_001"))
    assert_equal(1500, Cfc::Downloader.parse_int("1500"))
  end

  def test_parse_int_with_invalid_values
    assert_nil(Cfc::Downloader.parse_int(nil))
    assert_nil(Cfc::Downloader.parse_int(""))
    assert_nil(Cfc::Downloader.parse_int("-"))
  end

  def test_parse_date_with_valid_dates
    %w[2036-03-09 2025-12-31].each do |date_str|
      result = Cfc::Downloader.parse_date(date_str)
      refute_nil(result)
    end
  end

  def test_parse_date_with_invalid_values
    assert_nil(Cfc::Downloader.parse_date(nil))
    assert_nil(Cfc::Downloader.parse_date(""))
  end

  def test_clean_name_with_valid_names
    assert_equal("Smith", Cfc::Downloader.clean_name('"Smith"'))
    assert_equal("Alice", Cfc::Downloader.clean_name(' "Alice " '))
  end

  def test_clean_name_with_invalid_values
    assert_nil(Cfc::Downloader.clean_name(nil))
    assert_nil(Cfc::Downloader.clean_name(""))
  end

  def test_clean_city_with_valid_cities
    assert_equal("Toronto", Cfc::Downloader.clean_city('"Toronto"'))
  end

  def test_write_cached_data_creates_archive
    result = Cfc::Downloader.write_cached_data("test content", "etag123")
    assert(result)
    archive_path = File.join(@history_dir, "tdlist-#{Date.today.strftime("%Y%m%d")}.txt")
    assert(File.exist?(archive_path))
    FileUtils.rm_f(archive_path)
  end

  def test_write_cached_data_without_etag
    Cfc::Downloader.write_cached_data("test", nil)
    assert(File.exist?(@cache_file))
    refute(File.exist?(@etag_file))
  end

  def test_write_cached_data_with_etag
    FileUtils.rm_f(@etag_file)
    result = Cfc::Downloader.write_cached_data("test", "my-etag")
    assert(result)
    assert_equal("my-etag", File.read(@etag_file).strip)
  end

  def test_read_cached_data_with_existing_cache
    File.write(@cache_file, "cached data")
    result = Cfc::Downloader.read_cached_data
    assert_equal("cached data", result)
  end

  def test_read_cached_data_without_cache
    FileUtils.rm_f(@cache_file)
    result = Cfc::Downloader.read_cached_data
    assert_nil(result)
  end

  def test_read_cached_data_expires_after_7_days
    File.write(@cache_file, "old cached data")
    old_time = Time.now - (7 * 24 * 60 * 60 + 1)
    File.utime(old_time, old_time, @cache_file)
    result = Cfc::Downloader.read_cached_data
    assert_nil(result)
  end

  def test_sanitize_encoding_preserves_valid_utf8
    data = "Hello World"
    result = Cfc::Downloader.sanitize_encoding(data)
    assert_equal(data, result)
  end

  def test_line_valid_with_valid_utf8
    line = "test data"
    result = Cfc::Downloader.send(:line_valid?, line)
    assert(result)
  end

  def test_parse_players_with_multiple_lines
    csv_data = <<~CSV
      CFC#,Expiry,Last,First,Prov,City,Rating,High,Active Rtg,Active High
      100_001,2036-03-09,Smith,Alice,ON,Toronto,1500,1550,1490,1540
      100_002,2027-06-15,Johnson,Bob,BC,Vancouver,1450,1480,1440,1470
    CSV

    players = Cfc::Downloader.parse_players(csv_data)
    assert_equal(2, players.length)
  end

  def test_parse_players_empty_csv
    players = Cfc::Downloader.parse_players("")
    assert_equal([], players)
  end

  # NOTE: file_has_changed? makes real HTTP HEAD requests to CFC server.
  # These tests require network access and matching ETags, so they are skipped.
  def test_file_has_changed_with_missing_etag
    skip "requires network access"
  end

  def test_file_has_changed_with_matching_etag
    skip "requires network access and matching remote ETag"
  end

  def test_file_has_changed_with_mismatched_etag
    skip "requires network access"
  end
end
