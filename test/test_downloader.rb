# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestDownloader < Minitest::Test
  def self.cache_dir
    File.join(Dir.tmpdir, ".cfc-cache-test-#{Process.pid}")
  end

  def setup
    @cache_dir = self.class.cache_dir
    @history_dir = File.join(Dir.tmpdir, ".cfc-history-test-#{Process.pid}")
    FileUtils.rm_f(File.join(@cache_dir, "tdlist.txt")) rescue nil
    FileUtils.rm_f(File.join(@cache_dir, ".etag")) rescue nil
    Dir.glob(File.join(@history_dir, "*.txt")).each { |f| FileUtils.rm(f) } rescue nil
  end

  def teardown
    FileUtils.rm_f(File.join(@cache_dir, "tdlist.txt")) rescue nil
    FileUtils.rm_f(File.join(@cache_dir, ".etag")) rescue nil
    Dir.glob(File.join(@history_dir, "*.txt")).each { |f| FileUtils.rm(f) } rescue nil
  end

  def test_parse_csv_line_with_valid_data
    line = "100_001,2036-03-09,Smith,Alice,ON,Toronto,1500,1550,1490,1540"
    result = Cfc::Downloader.parse_csv_line(line)

    assert_equal(100_001, result[:cfc_id])
    assert_not_nil(result[:expire_date])
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
    ["2036-03-09", "2025-12-31"].each do |date_str|
      result = Cfc::Downloader.parse_date(date_str)
      assert_not_nil(result)
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
    FileUtils.mkdir_p(@history_dir) unless File.exist?(@history_dir)
    result = Cfc::Downloader.write_cached_data("test content", "etag123")
    assert(result)
    archive_path = File.join(@history_dir, "tdlist-#{Date.today.strftime("%Y%m%d")}.txt")
    assert(File.exist?(archive_path))
  end

  def test_write_cached_data_without_etag
    result = Cfc::Downloader.write_cached_data("test", nil)
    assert(result)
    refute(File.exist?(File.join(CACHE_DIR, ".etag")))
  end

  def test_write_cached_data_with_etag
    etag_file = File.join(CACHE_DIR, ".etag")
    if File.exist?(etag_file); FileUtils.rm(etag_file); end
    result = Cfc::Downloader.write_cached_data("test", "my-etag")
    assert(result)
    assert_equal("my-etag", File.read(etag_file).strip)
  end

  def test_read_cached_data_with_existing_cache
    File.write(File.join(@cache_dir, "tdlist.txt"), "cached data")
    result = Cfc::Downloader.read_cached_data
    assert_equal("cached data", result)
  end

  def test_read_cached_data_without_cache
    refute(File.exist?(File.join(@cache_dir, "tdlist.txt")))
    result = Cfc::Downloader.read_cached_data
    assert_nil(result)
  end

  def test_read_cached_data_expires_after_7_days
    File.write(File.join(@cache_dir, "tdlist.txt"), "old cached data")
    old_time = Time.now - (7 * 24 * 60 * 60 + 1)
    File.utime(old_time, old_time, File.join(@cache_dir, "tdlist.txt"))
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

  def test_file_has_changed_with_missing_etag
    FileUtils.rm_f(File.join(@cache_dir, ".etag")) rescue nil
    result = Cfc::Downloader.file_has_changed?
    assert(result)
  end

  def test_file_has_changed_with_matching_etag
    File.write(File.join(@cache_dir, "tdlist.txt"), "test data")
    File.write(File.join(@cache_dir, ".etag"), '"match"')
    refute(Cfc::Downloader.file_has_changed?)
  end

  def test_file_has_changed_with_mismatched_etag
    File.write(File.join(@cache_dir, "tdlist.txt"), "test data")
    File.write(File.join(@cache_dir, ".etag"), '"old-tag"')
    assert(Cfc::Downloader.file_has_changed?)
  end
end
