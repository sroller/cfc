# frozen_string_literal: true

require_relative "../db"

module Cfc
  module Commands
    class History
      def self.run(cfc_id, from: nil, to: nil, ids_file: nil)
        # Parse IDs from file if provided
        ids = if ids_file
                parse_ids_file(ids_file)
              else
                [Integer(cfc_id)]
              end

        db = Database.new

        # Format dates if provided
        from_date = format_date(from) if from
        to_date = format_date(to) if to

        ids.each do |id|
          display_player_history(db, id, from_date, to_date)
          puts if ids.length > 1 # Add blank line between players
        end

        db.close
      rescue ArgumentError => e
        puts "Invalid CFC ID: #{e.message}"
      end

      def self.parse_ids_file(filepath)
        return [] unless File.exist?(filepath)

        File.readlines(filepath).map(&:strip).reject(&:empty?).map(&:to_i)
      end

      def self.display_player_history(db, cfc_id, from_date, to_date)
        # Get player info
        player = db.get_player(cfc_id)
        if player.nil?
          puts "Player not found: #{cfc_id}"
          return
        end

        # Get history
        history = db.get_player_history(cfc_id, from_date: from_date, to_date: to_date)

        if history.empty?
          puts "No rating history found for player #{cfc_id}"
          return
        end

        # Display results
        display_history(player, history)
      end

      def self.format_date(date_str)
        # Convert YYYYMMDD to YYYY-MM-DD
        if date_str.length == 8
          "#{date_str[0..3]}-#{date_str[4..5]}-#{date_str[6..7]}"
        else
          date_str
        end
      end

      def self.display_history(player, history)
        name = "#{player["first_name"]} #{player["last_name"]}".strip
        puts "=== Rating History for #{name} (CFC ID: #{player["cfc_id"]}) ==="
        puts

        history.each do |record|
          date = record["rating_date"]
          rating = record["rating"] || 0
          active = record["active_rating"] || 0

          puts "#{date}: Rating: #{rating}, Active: #{active}"
        end

        puts
        puts "Total records: #{history.length}"
      end
    end
  end
end
