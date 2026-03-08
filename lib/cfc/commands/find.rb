# frozen_string_literal: true

require_relative "../db"

module Cfc
  module Commands
    class Find
      def self.run(last_name: nil, first_name: nil, province: nil, city: nil)
        db = Database.new
        players = db.find_players(
          last_name: last_name,
          first_name: first_name,
          province: province,
          city: city
        )
        db.close

        if players.empty?
          puts "No players found matching the criteria"
          return
        end

        display_results(players)
      end

      def self.display_results(players)
        puts "=== Search Results (#{players.length} player#{"s" if players.length > 1} found) ==="
        puts

        players.each do |player|
          name = "#{player["first_name"]} #{player["last_name"]}".strip
          cfc_id = player["cfc_id"]
          province = player["province"]
          city = player["city"]
          rating = player["rating"] || 0
          active_rating = player["active_rating"] || 0

          location = [city, province].compact.join(", ")
          location_str = location.empty? ? "" : " (#{location})"

          puts "#{cfc_id}: #{name}#{location_str} - Rating: #{rating}, Active: #{active_rating}"
        end
      end
    end
  end
end
