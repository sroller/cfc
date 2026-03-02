# frozen_string_literal: true

require_relative "db"
require "net/http"
require "uri"
require "date"
require "fileutils"

module Cfc
  class Downloader
    URL = "https://storage.googleapis.com/cfc-public/data/tdlist.txt"
    CACHE_DIR = File.expand_path("~/.cfc-cache")
    CACHE_FILE = File.join(CACHE_DIR, "tdlist.txt")
    CACHE_EXPIRY = 7 * 24 * 60 * 60 # 7 days in seconds
    FIXTURES_DIR = File.expand_path("../../test/fixtures", __dir__)

    def self.download_and_store(force: false)
      db = Database.new
      db.clear_data

      # Load fixtures in chronological order (ALL data, no deduplication)
      fixtures = Dir.glob(File.join(FIXTURES_DIR, "*.csv")).sort
      fixtures.each do |fixture|
        csv_data = File.read(fixture)
        players = parse_players(csv_data)
        # Extract date from filename: chess-canada-YYYYMMDD-HHMMSS.csv
        filename = File.basename(fixture)
        date_part = filename.split("-")[2]
        # Normalize to YYYY-MM-DD format
        download_date = "#{date_part[0..3]}-#{date_part[4..5]}-#{date_part[6..7]}"

        db.save_players(players, download_date)
      end

      # Load latest cached file (with deduplication)
      if File.exist?(CACHE_FILE)
        csv_data = File.read(CACHE_FILE)
        players = parse_players(csv_data)
        download_date = Date.today.to_s

        db.save_players(players, download_date)
      end

      db.close

      puts "Loaded #{fixtures.count} fixture snapshots + #{File.exist?(CACHE_FILE) ? "latest cached" : "no cache"}"
    end

    def self.fetch_csv(force: false)
      # Check if cache is valid
      cached_data = read_cached_data unless force

      if cached_data
        cached_data
      else
        new_data = download_from_url
        write_cached_data(new_data)
        new_data
      end
    end

    def self.download_from_url
      uri = URI.parse(URL)
      response = Net::HTTP.get(uri)
      response
    end

    def self.write_cached_data(data)
      FileUtils.mkdir_p(CACHE_DIR)
      # Ensure UTF-8 encoding, replace invalid sequences
      data.force_encoding(Encoding::UTF_8).valid_encoding? ? data : data.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "?")
      File.write(CACHE_FILE, data)
    end

    def self.read_cached_data
      return nil unless File.exist?(CACHE_FILE)

      # Check if cache is expired
      file_mtime = File.mtime(CACHE_FILE)
      if (Time.now - file_mtime) > CACHE_EXPIRY
        File.delete(CACHE_FILE)
        return nil
      end

      File.read(CACHE_FILE)
    end

    def self.parse_players(csv_data)
      lines = csv_data.lines
      # Skip header line
      lines[1..-1].map do |line|
        parse_csv_line(line)
      end.compact
    end

    def self.parse_csv_line(line)
      # Ensure proper encoding for parsing
      line = line.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "?")

      # Split by comma (simple split since CSV is malformed)
      # Format: CFC#,Expiry,Last,First,Prov,City,Rating,High,Active Rtg,Active High,FIDE Number,FIDE Rating
      parts = line.split(",")
      return nil if parts.length < 12

      # Clean each field
      cfc_id = parse_int(parts[0])
      expiry = parse_date(parts[1])
      last_name = clean_name(parts[2])
      first_name = clean_name(parts[3])
      province = clean_name(parts[4])
      # City might have quote issues, clean it
      city = clean_city(parts[5])
      rating = parse_int(parts[6])
      high_rating = parse_int(parts[7])
      active_rating = parse_int(parts[8])
      active_high_rating = parse_int(parts[9])
      fide_number = parts[10].to_s.strip
      fide_rating = parse_int(parts[11])

      {
        cfc_id: cfc_id,
        cfc_number: parts[0],
        expiry: expiry,
        last_name: last_name,
        first_name: first_name,
        province: province,
        city: city,
        rating: rating,
        high_rating: high_rating,
        active_rating: active_rating,
        active_high_rating: active_high_rating,
        fide_number: fide_number,
        fide_rating: fide_rating
      }
    end

    def self.parse_int(value)
      return nil if value.nil? || value.to_s.empty? || value.to_s == "-"
      Integer(value)
    rescue ArgumentError
      nil
    end

    def self.parse_date(value)
      return nil if value.nil? || value.to_s.empty? || value.to_s == "---"
      Date.parse(value.to_s).to_s
    rescue ArgumentError
      nil
    end

    def self.clean_name(value)
      return nil if value.nil? || value.to_s.empty?
      cleaned = value.to_s.gsub(/^["\s]+/, "").gsub(/["\s]+$/, "")
      return nil if cleaned == "---" || cleaned == "." || cleaned.empty?
      cleaned
    end

    def self.clean_city(value)
      return nil if value.nil? || value.to_s.empty?
      value.to_s.gsub(/^["\s]+/, "").gsub(/["\s]+$/, "").gsub(/"/, "")
    end
  end
end