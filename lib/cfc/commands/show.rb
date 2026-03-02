# frozen_string_literal: true

require_relative "../db"

module Cfc
  module Commands
    class Show
      def self.run(cfc_id, ids_file: nil)
        # Parse IDs from file if provided
        ids = if ids_file
                parse_ids_file(ids_file)
              else
                [Integer(cfc_id)]
              end

        db = Database.new

        ids.each do |id|
          display_player_info(db, id)
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

      def self.display_player_info(db, cfc_id)
        # Get player info with latest rating
        player = db.get_player(cfc_id)

        if player.nil?
          puts "Player not found: #{cfc_id}"
          return
        end

        display_player(player)
      end

      def self.display_player(player)
        name = "#{player["first_name"]} #{player["last_name"]}".strip
        province = player["province"]
        city = player["city"]
        rating = player["rating"] || 0
        active_rating = player["active_rating"] || 0
        fide_rating = player["fide_rating"] || 0
        rating_date = player["rating_date"]

        puts "=== Player Information ==="
        puts
        puts "Name:        #{name}"
        puts "CFC ID:      #{player["cfc_id"]}"
        puts "Province:    #{province}" if province
        puts "City:        #{city}" if city
        puts
        puts "Latest Rating Information (#{rating_date}):"
        puts "  Rating:       #{rating}"
        puts "  Active:       #{active_rating}"
        puts "  FIDE:         #{fide_rating}" if fide_rating&.positive?
      end
    end
  end
end
