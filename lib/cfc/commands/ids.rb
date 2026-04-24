# frozen_string_literal: true

require_relative "../db"

module Cfc
  module Commands
    module Ids
      # List IDs from file with player names
      def self.list(filepath, db: nil)
        filepath = File.expand_path(filepath)
        unless File.exist?(filepath)
          warn "Error: File not found: #{filepath}"
          return false
        end

        own_db = db.nil?
        db ||= Database.new
        lines = File.readlines(filepath).map(&:strip)

        puts "=== IDs from #{File.basename(filepath)} ==="
        puts

        lines.each do |line|
          next if line.empty? || line.start_with?("#")

          cfc_id = parse_line(line)
          next unless cfc_id

          player = db.get_player(cfc_id)
          if player
            name = "#{player["first_name"]} #{player["last_name"]}".strip
            province = player["province"]
            city = player["city"]
            location = [city, province].compact.join(", ")
            location_str = location.empty? ? "" : " (#{location})"
            puts "#{cfc_id} #{name}#{location_str}"
          else
            puts "#{cfc_id} [Not found in database]"
          end
        end

        puts
        db.close if own_db
        true
      end

      # Add ID to file with optional name
      def self.add(filepath, cfc_id, custom_name = nil, db: nil)
        filepath = File.expand_path(filepath)

        unless cfc_id.to_s =~ /^\d+$/
          warn "Error: Invalid CFC ID. Must be a number."
          return false
        end

        cfc_id = cfc_id.to_i

        # Check if ID already exists in file
        if File.exist?(filepath)
          lines = File.readlines(filepath).map(&:strip)
          existing_ids = lines.map { |line| parse_line(line) }.compact
          if existing_ids.include?(cfc_id)
            warn "Error: ID #{cfc_id} already exists in #{filepath}"
            return false
          end
        end

        # Look up player name if not provided
        name = custom_name
        if name.nil?
          own_db = db.nil?
          db ||= Database.new
          player = db.get_player(cfc_id)
          db.close if own_db

          if player
            name = "#{player["first_name"]} #{player["last_name"]}".strip
          else
            warn "Warning: ID #{cfc_id} not found in database, adding without name"
            name = ""
          end
        end

        # Create directory if it doesn't exist
        dir = File.dirname(filepath)
        FileUtils.mkdir_p(dir) unless File.exist?(dir)

        # Append to file
        line_to_add = name.empty? ? cfc_id.to_s : "#{cfc_id} #{name}"
        File.open(filepath, "a") { |f| f.puts(line_to_add) }

        warn "Added #{line_to_add} to #{filepath}"
        true
      end

      # Remove ID from file
      def self.remove(filepath, cfc_id)
        filepath = File.expand_path(filepath)

        unless File.exist?(filepath)
          warn "Error: File not found: #{filepath}"
          return false
        end

        unless cfc_id.to_s =~ /^\d+$/
          warn "Error: Invalid CFC ID. Must be a number."
          return false
        end

        cfc_id = cfc_id.to_i

        lines = File.readlines(filepath)
        filtered_lines = lines.reject { |line| parse_line(line.strip) == cfc_id }

        if filtered_lines.length == lines.length
          warn "Error: ID #{cfc_id} not found in #{filepath}"
          return false
        end

        File.write(filepath, filtered_lines.join)
        warn "Removed ID #{cfc_id} from #{filepath}"
        true
      end

      # Validate all IDs in file exist in database
      def self.validate(filepath, db: nil)
        filepath = File.expand_path(filepath)

        unless File.exist?(filepath)
          warn "Error: File not found: #{filepath}"
          return false
        end

        own_db = db.nil?
        db ||= Database.new
        lines = File.readlines(filepath).map(&:strip)

        total = 0
        valid = 0
        invalid = 0

        lines.each do |line|
          next if line.empty? || line.start_with?("#")

          cfc_id = parse_line(line)
          next unless cfc_id

          total += 1
          player = db.get_player(cfc_id)
          if player
            valid += 1
          else
            invalid += 1
            warn "  [NOT FOUND] #{cfc_id}"
          end
        end

        db.close if own_db

        puts
        puts "=== Validation Results ==="
        puts "Total IDs: #{total}"
        puts "Valid: #{valid}"
        puts "Invalid: #{invalid}"

        invalid.zero?
      end

      # Parse a line to extract CFC ID
      # Supports formats:
      #   123456
      #   123456 John Doe
      #   123456 # comment
      def self.parse_line(line)
        return nil if line.nil? || line.strip.empty?

        line = line.strip
        # Extract leading number
        match = line.match(/^(\d+)/)
        return nil unless match

        match[1].to_i
      end
    end
  end
end
