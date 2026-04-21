# frozen_string_literal: true

require "date"
require_relative "../db"
require_relative "../output_formatter"
require_relative "../mailer"

module Cfc
  module Commands
    class Show
      def self.run(cfc_id, ids_file: nil, db_path: nil, format: nil, mail: nil)
        # Parse IDs from file if provided
        ids = if ids_file
                parse_ids_file(ids_file)
              elsif cfc_id.is_a?(Array)
                cfc_id.map(&:to_i)
              else
                [Integer(cfc_id)]
              end

        # Default to HTML format when mailing
        format = "html" if mail && format.nil?

        db = Database.new(db_path)

        ids.each do |id|
          if format && format != "text"
            player = db.get_player(id)
            if player.nil?
              $stderr.puts "Player not found: #{id}"
            else
              output = OutputFormatter.format(player, format, type: :show, date_range: Date.today.to_s)
              puts output

              if mail
                name = "#{player["first_name"]} #{player["last_name"]}".strip
                Mailer.send_mail(mail, "Player Information - #{name}", output)
              end
            end
          else
            display_player_info(db, id)

            if mail
              player = db.get_player(id)
              if player
                output = OutputFormatter.format(player, "html", type: :show, date_range: Date.today.to_s)
                name = "#{player["first_name"]} #{player["last_name"]}".strip
                Mailer.send_mail(mail, "Player Information - #{name}", output)
              end
            end
          end
          puts if ids.length > 1 && (!format || format == "text")
        end

        db.close
      rescue ArgumentError => e
        $stderr.puts "Invalid CFC ID: #{e.message}"
      end

      def self.parse_ids_file(filepath)
        filepath = File.expand_path(filepath)
        return [] unless File.exist?(filepath)

        File.readlines(filepath).map(&:strip).reject(&:empty?).reject { |l| l.start_with?("#") }.map { |l| l.split.first.to_i }
      end

      def self.display_player_info(db, cfc_id)
        # Get player info with latest rating
        player = db.get_player(cfc_id)

        if player.nil?
          $stderr.puts "Player not found: #{cfc_id}"
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
        rating_date = player["rating_date"]
        expire_date = player["expire_date"]

        puts "=== Player Information ==="
        puts
        puts "Name:        #{name}"
        puts "CFC ID:      #{player["cfc_id"]}"
        puts "Province:    #{province}" if province
        puts "City:        #{city}" if city
        puts "Membership:  #{display_expire_date(expire_date)}" if expire_date
        puts
        puts "Latest Rating Information (#{rating_date}):"
        puts "  Rating:       #{rating}"
        puts "  Active:       #{active_rating}"
      end

      def self.display_expire_date(expire_date)
        return "Unknown" if expire_date.nil? || expire_date.empty?

        # Check for life membership (more than 50 years in the future)
        if is_life_membership?(expire_date)
          "LIFE"
        else
          expire_date
        end
      end

      def self.is_life_membership?(expire_date)
        return false if expire_date.nil? || expire_date.empty?

        date = Date.parse(expire_date)
        fifty_years_from_now = Date.today + (50 * 365.25).to_i
        date >= fifty_years_from_now
      end
    end
  end
end
