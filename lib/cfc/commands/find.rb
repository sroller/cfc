# frozen_string_literal: true

require "date"
require_relative "../db"
require_relative "../helpers"

module Cfc
  module Commands
    class Find
      def self.run(last_name: nil, first_name: nil, province: nil, city: nil, db_path: nil, format: nil, mail: nil)
        db = Database.new(db_path)
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

        count = players.length
        subject = "Search Results (#{count} player#{"s" if count != 1} found)"

        Helpers.output_result(players, format: format, mail: mail, type: :find,
                                       subject: subject, date_range: Date.today.to_s) do
          display_results(players)
        end
      end

      def self.display_results(players)
        puts "=== Search Results (#{players.length} player#{"s" if players.length > 1} found) ==="
        puts

        players.each do |player|
          name = "#{player["first_name"]} #{player["last_name"]}".strip
          cfc_id = player["cfc_id"]
          location = Helpers.format_location(player["city"], player["province"])
          location_str = location.empty? ? "" : " (#{location})"
          rating = player["rating"] || 0
          active_rating = player["active_rating"] || 0

          puts "#{cfc_id}: #{name}#{location_str} - Rating: #{rating}, Active: #{active_rating}"
        end
      end
    end
  end
end
