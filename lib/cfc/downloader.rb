# frozen_string_literal: true

require_relative "db"
require "net/http"
require "uri"
require "date"
require "fileutils"

module Cfc
  # Configuration constants for downloader operations
  URL = "https://storage.googleapis.com/cfc-public/data/tdlist.txt"
  CACHE_DIR = File.expand_path("~/.cfc-cache")
  HISTORY_DIR = File.expand_path("~/.cfc-history")
  CACHE_FILE = File.join(CACHE_DIR, "tdlist.txt")
  CACHE_ETAG_FILE = File.join(CACHE_DIR, ".etag")
  CACHE_EXPIRY = 7 * 24 * 60 * 60 # 7 days in seconds
  FIXTURES_DIR = File.expand_path("../../test/fixtures", __dir__)

  def self.download_and_store(force: false, cron: false)
    db = Database.new
    result = nil

    begin
      # Load fixtures chronologically for initial seeding (only if no data exists)
      existing_count = db.db.execute("SELECT COUNT(*) FROM player_ratings").first["COUNT(*)"]
      if existing_count.zero? || force
        fixtures = Dir.glob(File.join(FIXTURES_DIR, "*.csv")).sort
        fixtures.each do |fixture|
          csv_data = File.read(fixture)
          players = parse_players(csv_data)
          filename = File.basename(fixture)
          date_part = filename.split("-")[2] || ""
          next unless date_part.length >= 8

          download_date = "#{date_part[0..3]}-#{date_part[4..5]}-#{date_part[6..7]}"
          db.save_players(players, download_date, dedupe: false)
        end
      end

      # Download and cache the latest rating list
      csv_data = fetch_csv(force: force)

      # Only update database if data was actually downloaded
      if csv_data
        players = parse_players(csv_data)
        download_date = Date.today.to_s
        db.save_players(players, download_date)
        result = true
      end
    ensure
      db.close if db
    end

    puts "Loaded latest cached data" unless cron && result
    result
  rescue StandardError
    false
  end

  # Fetches CSV from URL with caching and ETag validation
  def self.fetch_csv(force: false)
    return nil unless File.exist?(CACHE_FILE)

    cached_data = read_cached_data unless force

    return nil if cached_data && !force && !file_has_changed?

    new_data = download_from_url
    etag = fetch_etag

    write_cached_data(new_data, etag)
    new_data
  end

  # Checks if remote file has changed by comparing ETags
  def self.file_has_changed?
    uri = URI.parse(URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"

    response = nil
    begin
      response = http.head(uri.path) || raise("No HEAD response")
    rescue StandardError
      # If HEAD request fails, assume file has changed
      return true
    end

    return true unless response

    remote_etag = response["etag"]
    return true if remote_etag.nil? || remote_etag.empty?

    # Check if local cache has matching ETag
    return true unless File.exist?(CACHE_ETAG_FILE)

    local_etag = File.read(CACHE_ETAG_FILE).strip
    remote_etag != local_etag
  end

  # Downloads file from URL and returns body as String
  def self.download_from_url
    uri = URI.parse(URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    response = http.get(uri.path)
    response.body
  rescue StandardError
    nil
  end

  # Fetches ETag from remote server using HEAD request
  def self.fetch_etag
    uri = URI.parse(URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"

    begin
      response = http.head(uri.path)
      response["etag"]
    rescue StandardError
      nil
    end
  end

  # Writes cache files and archives previous download
  def self.write_cached_data(data, etag = nil)
    FileUtils.mkdir_p(CACHE_DIR) unless File.exist?(CACHE_DIR)
    FileUtils.mkdir_p(HISTORY_DIR) unless File.exist?(HISTORY_DIR)

    encoded_data = sanitize_encoding(data)

    File.write(CACHE_FILE, encoded_data)

    return unless etag

    File.write(CACHE_ETAG_FILE, etag.to_s.strip)

    # Archive the file with datestamp for historical rebuilds
    archive_file = File.join(HISTORY_DIR, "tdlist-#{Date.today.strftime("%Y%m%d")}.txt")
    File.write(archive_file, encoded_data)
  end

  # Reads cached data and checks if it has expired
  def self.read_cached_data
    return nil unless File.exist?(CACHE_FILE)

    # Check if cache is expired
    file_mtime = File.mtime(CACHE_FILE)
    now = Time.now
    age_seconds = (now - file_mtime).to_f

    return nil if age_seconds > CACHE_EXPIRY

    File.read(CACHE_FILE)
  end

  # Parses CSV data from tdlist.txt into player records
  def self.parse_players(csv_data)
    lines = csv_data.lines
    # Skip header line (index 0), process rest
    parsed = lines[1..-1].map { |line| parse_csv_line(line) }
    parsed.compact
  end

  # Parses a single CSV line into a player hash
  def self.parse_csv_line(line)
    return nil unless line_valid?(line)

    # Split by comma (simple split since CSV is malformed with potential quoting issues)
    # Format: CFC#,Expiry,Last,First,Prov,City,Rating,High,Active Rtg,Active High
    parts = line.split(",")
    return nil if parts.length < 10

    {
      cfc_id: parse_int(parts[0]),
      expire_date: parse_date(parts[1]),
      last_name: clean_name(parts[2]),
      first_name: clean_name(parts[3]),
      province: clean_name(parts[4]),
      city: clean_city(parts[5]),
      rating: parse_int(parts[6]),
      high_rating: parse_int(parts[7]),
      active_rating: parse_int(parts[8]),
      active_high_rating: parse_int(parts[9])
    }
  end

  # Parses integer value from string, returns nil for invalid values
  def self.parse_int(value)
    return nil unless value
    value = value.to_s.strip

    # Handle empty, dash, and NULL values
    return nil if value.empty? || value == "-" || value == "nil" || value == "NULL"

    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end

  # Parses date from string, returns nil for invalid dates
  def self.parse_date(value)
    return nil unless value

    value = value.to_s
    return nil if value.empty? || value == "---" || value == "---"

    Date.parse(value).to_s
  rescue ArgumentError
    nil
  end

  # Cleans name field by trimming quotes and whitespace
  def self.clean_name(value)
    return nil unless value
    return nil if value.to_s.empty?

    cleaned = value.to_s.gsub(/^["\s]+/, "").gsub(/["\s]+$/, "")
    return nil if cleaned == "---" || cleaned == "." || cleaned.empty?

    cleaned
  end

  # Cleans city field by removing quotes (but not empty)
  def self.clean_city(value)
    return nil unless value

    cleaned = value.to_s.strip
    cleaned.gsub(/^["\s]+/, "").gsub(/["\s]+$/, "").gsub(/"/, "")
  rescue StandardError
    nil
  end

  # Checks if line has valid UTF-8 encoding
  def self.line_valid?(line)
    begin
      line.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "?")
    rescue Encoding::InvalidByteSequenceError
      false
    end
  end

  # Ensures data has valid UTF-8 encoding
  def self.sanitize_encoding(data)
    utf8_data = data.force_encoding(Encoding::UTF_8)

    return utf8_data if utf8_data.valid_encoding?

    sanitized = utf8_data.encode("UTF-8", "binary",
      invalid: :replace,
      undef: :replace,
      replace: "?")

    sanitized
  rescue StandardError
    data
  end
end
