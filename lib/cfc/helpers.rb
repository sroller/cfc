# frozen_string_literal: true

require "date"

module Cfc
  module Helpers
    PLAYER_SORT_KEY = lambda { |p|
      [p[:province] || p["province"] || "",
       p[:city] || p["city"] || "",
       p[:last_name] || p["last_name"] || "",
       p[:first_name] || p["first_name"] || ""]
    }

    def self.parse_ids_file(filepath)
      filepath = File.expand_path(filepath)
      abort "Error: IDs file not found: #{filepath}" unless File.exist?(filepath)

      File.readlines(filepath)
          .map(&:strip)
          .reject(&:empty?)
          .reject { |l| l.start_with?("#") }
          .map { |l| l.split.first.to_i }
          .reject(&:zero?)
    end

    def self.parse_ids(ids_string)
      ids_string.split(",").map(&:strip).map(&:to_i)
    end

    def self.normalize_date(date_str)
      return date_str if date_str.nil? || date_str.include?("-")
      return date_str unless date_str.length == 8

      "#{date_str[0..3]}-#{date_str[4..5]}-#{date_str[6..7]}"
    rescue StandardError
      date_str
    end

    def self.valid_date_format?(date_str)
      return false if date_str.nil? || date_str.empty?

      date_str.match?(/^\d{4}-\d{2}-\d{2}$/) || date_str.match?(/^\d{8}$/)
    end

    def self.life_membership?(expire_date)
      return false if expire_date.nil? || expire_date.to_s.empty?

      date = Date.parse(expire_date.to_s)
      date >= Date.today + (50 * 365.25).to_i
    rescue ArgumentError, Date::Error
      false
    end

    def self.display_expire(expire_date)
      return "Unknown" if expire_date.nil? || expire_date.to_s.empty?

      life_membership?(expire_date) ? "LIFE" : expire_date.to_s
    end

    def self.format_location(city, province)
      parts = [city, province].compact
      parts.any? ? parts.join(", ") : ""
    end

    # Unified output dispatch: renders text or formatted output, optionally sends email.
    # Pass a block for text-mode rendering.
    def self.output_result(data, format:, mail:, type:, subject:, date_range: nil, &text_block)
      require_relative "output_formatter"
      require_relative "mailer"

      format = "html" if mail && (format.nil? || format == "text")

      if format && format != "text"
        output = OutputFormatter.format(data, format, type: type, date_range: date_range)
        puts output
        Mailer.send_mail(mail, subject, output) if mail
      else
        text_block&.call
        if mail
          output = OutputFormatter.format(data, "html", type: type, date_range: date_range)
          Mailer.send_mail(mail, subject, output)
        end
      end
    end
  end
end
