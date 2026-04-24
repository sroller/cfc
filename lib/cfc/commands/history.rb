# frozen_string_literal: true

require_relative "../db"
require_relative "../helpers"

module Cfc
  module Commands
    class History
      def self.run(cfc_id, from: nil, to: nil, ids_file: nil, db_path: nil, format: nil, mail: nil)
        ids = if ids_file
                Helpers.parse_ids_file(ids_file)
              else
                [Integer(cfc_id)]
              end

        db = Database.new(db_path)

        from_date = Helpers.normalize_date(from) if from
        to_date = Helpers.normalize_date(to) if to

        ids.each do |id|
          player = db.get_player(id)
          if player.nil?
            warn "Player not found: #{id}"
            next
          end

          history = db.get_player_history(id, from_date: from_date, to_date: to_date)
          if history.empty?
            warn "No rating history found for player #{id}"
            next
          end

          data = { player: player, history: history }
          date_range = build_date_range(from_date, to_date)
          name = "#{player["first_name"]} #{player["last_name"]}".strip
          subject = date_range ? "Rating History - #{name} (#{date_range})" : "Rating History - #{name}"

          Helpers.output_result(data, format: format, mail: mail, type: :history,
                                      subject: subject, date_range: date_range) do
            display_history(player, history)
          end
          puts if ids.length > 1 && (format.nil? || format == "text")
        end

        db.close
      rescue ArgumentError => e
        warn "Invalid CFC ID: #{e.message}"
      end

      def self.build_date_range(from_date, to_date)
        return nil unless from_date || to_date
        return to_date if from_date.nil?
        return from_date if to_date.nil?

        "#{from_date} to #{to_date}"
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
