# frozen_string_literal: true

require_relative "../db"
require_relative "../output_formatter"
require_relative "../mailer"

module Cfc
  module Commands
    class History
      def self.run(cfc_id, from: nil, to: nil, ids_file: nil, db_path: nil, format: nil, mail: nil)
        # Parse IDs from file if provided
        ids = if ids_file
                parse_ids_file(ids_file)
              else
                [Integer(cfc_id)]
              end

        # Default to HTML format when mailing
        format = "html" if mail && format.nil?

        db = Database.new(db_path)

        # Format dates if provided
        from_date = format_date(from) if from
        to_date = format_date(to) if to

        ids.each do |id|
          if format && format != "text"
            output = capture_player_history(db, id, from_date, to_date, format)
            puts output

            if mail
              date_range = build_date_range(from_date, to_date)
              player = db.get_player(id)
              name = player ? "#{player["first_name"]} #{player["last_name"]}".strip : "Player #{id}"
              subject = date_range ? "Rating History - #{name} (#{date_range})" : "Rating History - #{name}"
              Mailer.send_mail(mail, subject, output)
            end
          else
            display_player_history(db, id, from_date, to_date)

            if mail
              output = capture_player_history(db, id, from_date, to_date, "html")
              date_range = build_date_range(from_date, to_date)
              name = "Player #{id}"
              begin
                player = db.get_player(id)
                name = "#{player["first_name"]} #{player["last_name"]}".strip if player
              rescue StandardError
                # Keep default name
              end
              subject = date_range ? "Rating History - #{name} (#{date_range})" : "Rating History - #{name}"
              Mailer.send_mail(mail, subject, output)
            end
          end
          puts if ids.length > 1 && (!format || format == "text") # Add blank line between players
        end

        db.close
      rescue ArgumentError => e
        $stderr.puts "Invalid CFC ID: #{e.message}"
      end

      def self.capture_player_history(db, cfc_id, from_date, to_date, format)
        player = db.get_player(cfc_id)
        if player.nil?
          return "Player not found: #{cfc_id}"
        end

        history = db.get_player_history(cfc_id, from_date: from_date, to_date: to_date)
        if history.empty?
          return "No rating history found for player #{cfc_id}"
        end

        date_range = build_date_range(from_date, to_date)
        OutputFormatter.format({ player: player, history: history }, format, type: :history, date_range: date_range)
      end

      def self.build_date_range(from_date, to_date)
        return nil unless from_date || to_date
        return to_date if from_date.nil?
        return from_date if to_date.nil?
        "#{from_date} to #{to_date}"
      end

      def self.parse_ids_file(filepath)
        filepath = File.expand_path(filepath)
        return [] unless File.exist?(filepath)

        File.readlines(filepath).map(&:strip).reject(&:empty?).reject { |l| l.start_with?("#") }.map { |l| l.split.first.to_i }
      end

      def self.display_player_history(db, cfc_id, from_date, to_date)
        # Get player info
        player = db.get_player(cfc_id)
        if player.nil?
          $stderr.puts "Player not found: #{cfc_id}"
          return
        end

        # Get history
        history = db.get_player_history(cfc_id, from_date: from_date, to_date: to_date)

        if history.empty?
          $stderr.puts "No rating history found for player #{cfc_id}"
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
