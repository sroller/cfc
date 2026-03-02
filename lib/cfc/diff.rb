# frozen_string_literal: true

require "csv"
require "stringio"
require "fileutils"
require "date"

module Cfc
  class Diff
    def self.run(from: nil, to: nil)
      # Get ratings from database for from and to dates
      db = Database.new
      from_players = get_players_by_date(db, from)
      to_players = get_players_by_date(db, to)
      db.close

      if from_players.nil? || to_players.nil?
        puts "Could not find data for #{from} and #{to}"
        return
      end

      # Find changes
      changes = compare_players(from_players, to_players)

      # Print results
      print_changes(changes)
    end

    def self.get_players_by_date(db, date)
      db.get_rating_history_by_date(date)
    end

    def self.parse_players(csv_data)
      lines = csv_data.lines
      lines[1..-1].map do |line|
        parse_csv_line(line)
      end.compact
    end

    def self.parse_csv_line(line)
      # Simple split by comma for malformed CSV
      parts = line.split(",")
      return nil if parts.length < 12

      last_name = clean_name(parts[2])
      first_name = clean_name(parts[3])

      # Skip entries where name looks like a date or invalid data
      return nil if invalid_name?(last_name) || invalid_name?(first_name)

      {
        cfc_id: parts[0],
        last_name: last_name,
        first_name: first_name,
        rating: parse_int(parts[6]),
        active_rating: parse_int(parts[8])
      }
    end

    def self.invalid_name?(name)
      return true if name.nil? || name.empty?
      # Check if it looks like a date or invalid placeholder
      return true if name =~ /^[A-Z][a-z]+ [A-Z][a-z]+ \d{4}$/ || # "February 2025"
                      name =~ /^\d+$/ || # Just numbers
                      name == "." || name == "---"
      false
    end

    def self.parse_int(value)
      return nil if value.nil? || value.to_s.empty? || value.to_s == "-"
      Integer(value)
    rescue ArgumentError
      nil
    end

    def self.clean_name(value)
      return nil if value.nil? || value.to_s.empty?
      cleaned = value.to_s.gsub(/^[\"\s]+/, "").gsub(/[\"\s]+$/, "").gsub(/"/, "")
      return nil if cleaned == "---" || cleaned == "." || cleaned.empty?
      cleaned
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
          name = "#{p[:first_name]} #{p[:last_name]}"
          puts "  + #{p[:cfc_id]} (#{name}) Rating: #{p[:rating]} Active: #{p[:active_rating]}"
        end
        puts
      end

      # Removed players
      if changes[:removed].any?
        puts "Removed Players: #{changes[:removed].count}"
        changes[:removed].each do |p|
          name = "#{p[:first_name]} #{p[:last_name]}"
          puts "  - #{p[:cfc_id]} (#{name}) Rating: #{p[:rating]} Active: #{p[:active_rating]}"
        end
        puts
      end

      # Changed players
      if changes[:changed].any?
        puts "Changed Players: #{changes[:changed].count}"
        changes[:changed].each do |c|
          name = "#{c[:to][:first_name]} #{c[:to][:last_name]}"
          puts "  #{c[:cfc_id]} (#{name}): #{c[:from][:rating]} -> #{c[:to][:rating]}"
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