# frozen_string_literal: true

require "date"
require_relative "../db"
require_relative "../helpers"
require_relative "../player_resolver"

module Cfc
  module Commands
    class Show
      def self.run(cfc_id, ids_file: nil, db_path: nil, format: nil, mail: nil)
        db = Database.new(db_path)

        ids = if ids_file
                Helpers.parse_ids_file(ids_file)
              elsif cfc_id.is_a?(Array)
                cfc_id.map(&:to_i)
              else
                PlayerResolver.resolve(cfc_id, db: db)
              end

        ids.each do |id|
          player = db.get_player(id)
          if player.nil?
            warn "Player not found: #{id}"
            next
          end

          name = "#{player["first_name"]} #{player["last_name"]}".strip
          Helpers.output_result(player, format: format, mail: mail, type: :show,
                                        subject: "Player Information - #{name}",
                                        date_range: Date.today.to_s) do
            display_player(player)
          end
          puts if ids.length > 1 && (format.nil? || format == "text")
        end

        db.close
      rescue ArgumentError => e
        warn "Invalid CFC ID: #{e.message}"
      end

      def self.display_player(player)
        name = "#{player["first_name"]} #{player["last_name"]}".strip
        province = player["province"]
        city = player["city"]
        rating = player["rating"] || 0
        active_rating = player["active_rating"] || 0
        rating_date = player["rating_date"]
        expire_date = player["expire_date"]

        puts "=== Player Information ==="
        puts
        puts "Name:        #{name}"
        puts "CFC ID:      #{player["cfc_id"]}"
        puts "Province:    #{province}" if province
        puts "City:        #{city}" if city
        puts "Membership:  #{Helpers.display_expire(expire_date)}" if expire_date
        puts
        puts "Latest Rating Information (#{rating_date}):"
        puts "  Rating:       #{rating}"
        puts "  Active:       #{active_rating}"
      end
    end
  end
end
