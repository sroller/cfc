# frozen_string_literal: true

require "csv"
require "stringio"
require "fileutils"
require "date"

module Cfc
  class Diff
    FIXTURES_DIR = File.join(__dir__, "../../test/fixtures")

    def self.run(from: nil, to: nil)
      # Find all fixture files and sort by date
      fixtures = Dir.glob(File.join(FIXTURES_DIR, "*.csv")).sort

      if fixtures.empty?
        puts "No fixtures found in #{FIXTURES_DIR}"
        return
      end

      # Extract dates from filenames: chess-canada-YYYYMMDD-HHMMSS.csv
      get_date = ->(path) { File.basename(path).split("-")[2] }
      sorted_fixtures = fixtures.sort_by { |f| get_date[f] }

      # Determine from and to dates
      from_date = from || get_date.call(sorted_fixtures[-2])
      to_date = to || get_date.call(sorted_fixtures[-1])

      from_data = load_fixture(from_date)
      to_data = load_fixture(to_date)

      if from_data.nil? || to_data.nil?
        puts "Could not load fixtures for #{from_date} and #{to_date}"
        puts "Available: #{sorted_fixtures.map { |f| get_date[f] }.join(", ")}"
        puts "from_data: #{from_data.inspect}"
        puts "to_data: #{to_data.inspect}"
        return
      end

      # Parse players
      from_players = parse_players(from_data)
      to_players = parse_players(to_data)

      # Find changes
      changes = compare_players(from_players, to_players)

      # Print results
      print_changes(changes)
    end

    def self.load_fixture(date)
      # Find fixture by date prefix in filename
      fixtures = Dir.glob(File.join(FIXTURES_DIR, "chess-canada-#{date}*.csv"))
      return nil if fixtures.empty?

      fixture_path = fixtures.first
      data = File.read(fixture_path).encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "?")
      data
    end

    def self.parse_players(csv_data)
      lines = csv_data.lines
      lines[1..-1].map do |line|
        parts = line.split(",")
        return nil if parts.length < 3

        {
          cfc_id: parts[0],
          rating: parts[6],
          active_rating: parts[8]
        }
      end.compact
    end

    def self.compare_players(from_players, to_players)
      from_hash = from_players.map { |p| [p[:cfc_id], p] }.to_h
      to_hash = to_players.map { |p| [p[:cfc_id], p] }.to_h

      changes = {
        new: [],
        removed: [],
        changed: []
      }

      # New players (in to but not in from)
      (to_hash.keys - from_hash.keys).each do |id|
        changes[:new] << { cfc_id: id, **to_hash[id] }
      end

      # Removed players (in from but not in to)
      (from_hash.keys - to_hash.keys).each do |id|
        changes[:removed] << { cfc_id: id, **from_hash[id] }
      end

      # Changed players (in both but different)
      (from_hash.keys & to_hash.keys).each do |id|
        from_p = from_hash[id]
        to_p = to_hash[id]

        if from_p != to_p
          changes[:changed] << {
            cfc_id: id,
            from: from_p,
            to: to_p
          }
        end
      end

      changes
    end

    def self.print_changes(changes)
      puts "=== Rating Changes ==="
      puts

      # New players
      if changes[:new].any?
        puts "New Players: #{changes[:new].count}"
        changes[:new].each do |p|
          puts "  + #{p[:cfc_id]} Rating: #{p[:rating]} Active: #{p[:active_rating]}"
        end
        puts
      end

      # Removed players
      if changes[:removed].any?
        puts "Removed Players: #{changes[:removed].count}"
        changes[:removed].each do |p|
          puts "  - #{p[:cfc_id]} Rating: #{p[:rating]} Active: #{p[:active_rating]}"
        end
        puts
      end

      # Changed players
      if changes[:changed].any?
        puts "Changed Players: #{changes[:changed].count}"
        changes[:changed].each do |c|
          puts "  #{c[:cfc_id]}: #{c[:from][:rating]} -> #{c[:to][:rating]}"
          puts "         Active: #{c[:from][:active_rating]} -> #{c[:to][:active_rating]}"
        end
        puts
      end

      # Summary
      puts "Summary:"
      puts "  New: #{changes[:new].count}"
      puts "  Removed: #{changes[:removed].count}"
      puts "  Changed: #{changes[:changed].count}"
    end
  end
end