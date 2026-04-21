# frozen_string_literal: true

require "date"
require_relative "../db"
require_relative "../output_formatter"
require_relative "../mailer"

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

        # Default to HTML format when mailing
        format = "html" if mail && format.nil?

        if format && format != "text"
          output = OutputFormatter.format(players, format, type: :find, date_range: Date.today.to_s)
          puts output

          if mail
            Mailer.send_mail(mail, "Search Results (#{players.length} player#{"s" if players.length != 1} found)", output)
          end
        else
          display_results(players)

          if mail
            output = OutputFormatter.format(players, "html", type: :find, date_range: Date.today.to_s)
            Mailer.send_mail(mail, "Search Results (#{players.length} player#{"s" if players.length != 1} found)", output)
          end
        end
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
