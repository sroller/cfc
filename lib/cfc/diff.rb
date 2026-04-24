# frozen_string_literal: true

require "csv"
require "date"
require_relative "helpers"

module Cfc
  class Diff
    def self.run(from: nil, to: nil, ids: nil, ids_file: nil, show_spinner: true, db_path: nil, format: nil, mail: nil)
      spinner = Thread.new { run_spinner } if show_spinner && $stdout.tty?

      db = Database.new(db_path)
      from = Helpers.normalize_date(from) if from
      to = Helpers.normalize_date(to) if to

      if from.nil? || to.nil?
        default_from, default_to = get_default_dates(db)
        from ||= default_from
        to ||= default_to
      end

      id_filter = Helpers.parse_ids(ids) if ids
      id_filter = Helpers.parse_ids_file(ids_file) if ids_file

      from_players = get_players_by_date(db, from)
      to_players = get_players_by_date(db, to)
      db.close

      spinner&.kill
      print "\r\e[K" if spinner

      if from_players.empty? || to_players.empty?
        warn "Could not find data for #{from} and #{to}"
        return
      end

      if id_filter
        from_players = from_players.select { |p| id_filter.include?(p[:cfc_id]) }
        to_players = to_players.select { |p| id_filter.include?(p[:cfc_id]) }
      end

      changes = compare_players(from_players, to_players)
      date_range = "#{from} to #{to}"

      Helpers.output_result(changes, format: format, mail: mail, type: :diff,
                                     subject: "Rating Changes (#{date_range})", date_range: date_range) do
        print_changes(changes)
      end
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
        warn "Not enough rating snapshots available (need at least 2, found #{dates.length})"
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

      if changes[:new].any?
        puts "New Players: #{changes[:new].count}"
        changes[:new].sort_by(&Helpers::PLAYER_SORT_KEY).each do |p|
          name = "#{p[:first_name]} #{p[:last_name]}"
          location = Helpers.format_location(p[:city], p[:province])
          location_str = location.empty? ? "" : " (#{location})"
          expire_info = Helpers.display_expire(p[:expire_date])
          puts "  + #{p[:cfc_id]} #{name}#{location_str}: Rating: #{p[:rating]}, Active: #{p[:active_rating]}, Membership: #{expire_info}"
        end
        puts
      end

      if changes[:removed].any?
        puts "Retired Players: #{changes[:removed].count}"
        changes[:removed].sort_by(&Helpers::PLAYER_SORT_KEY).each do |p|
          name = "#{p[:first_name]} #{p[:last_name]}"
          location = Helpers.format_location(p[:city], p[:province])
          location_str = location.empty? ? "" : " (#{location})"
          expire_info = Helpers.display_expire(p[:expire_date])
          puts "  - #{p[:cfc_id]} #{name}#{location_str}: Last Rating: #{p[:rating]}, Last Active: #{p[:active_rating]}, Membership: #{expire_info}"
        end
        puts
      end

      if changes[:changed].any?
        puts "Changed Players: #{changes[:changed].count}"
        changes[:changed].sort_by(&Helpers::PLAYER_SORT_KEY).each do |c|
          name = "#{c[:to][:first_name]} #{c[:to][:last_name]}"
          location = Helpers.format_location(c[:to][:city], c[:to][:province])
          location_str = location.empty? ? "" : " (#{location})"
          expire_info = Helpers.display_expire(c[:to][:expire_date])

          changes_list = []
          changes_list << "Rating: #{c[:from][:rating]} -> #{c[:to][:rating]}" if c[:rating_changed]
          changes_list << "Active: #{c[:from][:active_rating]} -> #{c[:to][:active_rating]}" if c[:active_changed]

          puts "  #{c[:cfc_id]} #{name}#{location_str}: #{changes_list.join(", ")}, Membership: #{expire_info}"
        end
        puts
      end

      # Summary
      puts "Summary:"
      puts "  New: #{changes[:new].count}"
      puts "  Retired: #{changes[:removed].count}" if changes[:removed].any?
      puts "  Changed: #{changes[:changed].count}"
    end
  end
end
