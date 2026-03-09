# frozen_string_literal: true

require "csv"
require "stringio"
require "fileutils"
require "date"

module Cfc
  class Diff
    def self.run(from: nil, to: nil, ids: nil, ids_file: nil, show_spinner: true, db_path: nil)
      spinner = Thread.new { run_spinner } if show_spinner

      # Get ratings from database for from and to dates
      db = Database.new(db_path)

      # Get default dates if not provided (latest two available snapshots)
      from, to = get_default_dates(db) if from.nil? || to.nil?

      # Parse IDs filter if provided
      id_filter = parse_ids(ids) if ids
      id_filter = parse_ids_file(ids_file) if ids_file

      from_players = get_players_by_date(db, from)
      to_players = get_players_by_date(db, to)
      db.close

      # Stop spinner
      spinner&.kill
      print "\r\e[K" if spinner # Clear the spinner line only if spinner was running

      if from_players.empty? || to_players.empty?
        puts "Could not find data for #{from} and #{to}"
        return
      end

      # Apply ID filter if provided
      if id_filter
        from_players = from_players.select { |p| id_filter.include?(p[:cfc_id]) }
        to_players = to_players.select { |p| id_filter.include?(p[:cfc_id]) }
      end

      # Find changes
      changes = compare_players(from_players, to_players)

      # Print results
      print_changes(changes)
    end

    def self.run_spinner
      chars = %w[| / - \\]
      i = 0
      loop do
        print "\r#{chars[i]} Working..."
        i = (i + 1) % chars.length
        sleep(0.1)
      end
    end

    def self.parse_ids(ids_string)
      ids_string.split(",").map(&:strip).map(&:to_i)
    end

    def self.parse_ids_file(filepath)
      return nil unless File.exist?(filepath)

      File.readlines(filepath).map(&:strip).reject(&:empty?).map(&:to_i).reject(&:zero?)
    end

    def self.get_players_by_date(db, date)
      results = db.get_rating_history_by_date_with_player_info(date)
      # Convert string keys to symbol keys for consistency
      results.map do |row|
        {
          cfc_id: row["cfc_id"],
          first_name: row["first_name"],
          last_name: row["last_name"],
          province: row["province"],
          city: row["city"],
          rating: row["rating"],
          active_rating: row["active_rating"],
          expire_date: row["expire_date"]
        }
      end
    end

    def self.get_default_dates(db)
      # Get the two most recent rating dates
      dates = db.db.execute(<<-SQL).map { |row| row["rating_date"] }
        SELECT DISTINCT rating_date FROM player_ratings ORDER BY rating_date DESC LIMIT 2
      SQL

      if dates.length < 2
        puts "Not enough rating snapshots available (need at least 2, found #{dates.length})"
        exit(1)
      end

      [dates[1], dates[0]] # [older, newer]
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
        changes[:new] << to_hash[id].dup
      end

      # Removed players (in from but not in to)
      (from_hash.keys - to_hash.keys).each do |id|
        changes[:removed] << from_hash[id].dup
      end

      # Changed players (in both but different)
      (from_hash.keys & to_hash.keys).each do |id|
        from_p = from_hash[id]
        to_p = to_hash[id]

        # Only track if national rating or active rating changed
        rating_changed = from_p[:rating] != to_p[:rating]
        active_changed = from_p[:active_rating] != to_p[:active_rating]

        next unless rating_changed || active_changed

        changes[:changed] << {
          cfc_id: id,
          from: from_p,
          to: to_p,
          rating_changed: rating_changed,
          active_changed: active_changed
        }
      end

      changes
    end

    def self.print_changes(changes)
      puts "=== Rating Changes ==="
      puts

      # Sort players by province, then city
      sort_key = ->(p) { [p[:province] || "", p[:city] || "", p[:last_name] || "", p[:first_name] || ""] }

      # New players
      if changes[:new].any?
        puts "New Players: #{changes[:new].count}"
        changes[:new].sort_by(&sort_key).each do |p|
          name = "#{p[:first_name]} #{p[:last_name]}"
          province = p[:province]
          city = p[:city]
          location_parts = [city, province].compact
          location = location_parts.any? ? " (#{location_parts.join(", ")})" : ""
          expire_info = display_expire_info(p[:expire_date])
          puts "  + #{p[:cfc_id]} #{name}#{location}: Rating: #{p[:rating]}, Active: #{p[:active_rating]}, #{expire_info}"
        end
        puts
      end

      # Retired players (no longer in newer rating list) - only show if there are any
      if changes[:removed].any?
        puts "Retired Players: #{changes[:removed].count}"
        changes[:removed].sort_by(&sort_key).each do |p|
          name = "#{p[:first_name]} #{p[:last_name]}"
          province = p[:province]
          city = p[:city]
          location_parts = [city, province].compact
          location = location_parts.any? ? " (#{location_parts.join(", ")})" : ""
          expire_info = display_expire_info(p[:expire_date])
          puts "  - #{p[:cfc_id]} #{name}#{location}: Last Rating: #{p[:rating]}, Last Active: #{p[:active_rating]}, #{expire_info}"
        end
        puts
      end

      # Changed players - only show if national rating or active rating changed
      if changes[:changed].any?
        puts "Changed Players: #{changes[:changed].count}"
        changes[:changed].sort_by(&sort_key).each do |c|
          name = "#{c[:to][:first_name]} #{c[:to][:last_name]}"
          province = c[:to][:province]
          city = c[:to][:city]
          location_parts = [city, province].compact
          location = location_parts.any? ? " (#{location_parts.join(", ")})" : ""
          expire_info = display_expire_info(c[:to][:expire_date])

          changes_list = []
          changes_list << "Rating: #{c[:from][:rating]} -> #{c[:to][:rating]}" if c[:rating_changed]
          changes_list << "Active: #{c[:from][:active_rating]} -> #{c[:to][:active_rating]}" if c[:active_changed]

          puts "  #{c[:cfc_id]} #{name}#{location}: #{changes_list.join(", ")}, #{expire_info}"
        end
        puts
      end

      # Summary
      puts "Summary:"
      puts "  New: #{changes[:new].count}"
      puts "  Retired: #{changes[:removed].count}" if changes[:removed].any?
      puts "  Changed: #{changes[:changed].count}"
    end

    def self.display_expire_info(expire_date)
      return "Membership: Unknown" if expire_date.nil? || expire_date.empty?

      # Check for life membership (more than 50 years in the future)
      if Cfc::Commands::Show.is_life_membership?(expire_date)
        "Membership: LIFE"
      else
        "Membership: #{expire_date}"
      end
    end
  end
end
