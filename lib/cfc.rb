# frozen_string_literal: true

require_relative "cfc/version"
require_relative "cfc/db"
require_relative "cfc/downloader"
require_relative "cfc/diff"
require_relative "cfc/output_formatter"
require "thor"

module Cfc
  class Error < StandardError; end

  class CLI < Thor
    desc "download", "Download the latest CFC rating list"
    option :force, aliases: "-f", desc: "Force download even if cache is valid", type: :boolean, default: false
    option :cron, desc: "Cron mode - silent unless error, exits 0 if new data, 1 if no change", type: :boolean,
                  default: false
    def download
      result = Downloader.download_and_store(force: options[:force], cron: options[:cron])
      exit(result ? 0 : 1) if options[:cron]
    end

    desc "diff", "Compare rating snapshots between dates"
    option :from, desc: "Start date (YYYY-MM-DD or YYYYMMDD)", type: :string
    option :to, desc: "End date (YYYY-MM-DD or YYYYMMDD)", type: :string
    option :ids, desc: "Comma-separated list of CFC IDs to filter", type: :string
    option :ids_file, desc: "File containing CFC IDs (one per line)", type: :string
    option :format, desc: "Output format: text (default), html, csv", type: :string, default: "text"
    option :mail, desc: "Comma-separated list of email addresses to send output to", type: :string
    def diff
      if options[:ids] && options[:ids_file]
        $stderr.puts "Error: Cannot use both --ids and --ids_file options"
        exit(1)
      end
      if options[:from] && !CLI.valid_date_format?(options[:from])
        $stderr.puts "Error: Invalid date format for --from. Use YYYY-MM-DD or YYYYMMDD (e.g., 2026-01-01 or 20260101)"
        exit(1)
      end
      if options[:to] && !CLI.valid_date_format?(options[:to])
        $stderr.puts "Error: Invalid date format for --to. Use YYYY-MM-DD or YYYYMMDD (e.g., 2026-01-01 or 20260101)"
        exit(1)
      end
      unless %w[text html csv].include?(options[:format])
        $stderr.puts "Error: Invalid format '#{options[:format]}'. Use text, html, or csv"
        exit(1)
      end
      Diff.run(from: options[:from], to: options[:to], ids: options[:ids], ids_file: options[:ids_file], format: options[:format], mail: options[:mail])
    end

    desc "history CFC_ID", "Show rating history for a player"
    option :from, desc: "Start date (YYYY-MM-DD or YYYYMMDD)", type: :string
    option :to, desc: "End date (YYYY-MM-DD or YYYYMMDD)", type: :string
    option :ids_file, desc: "File containing CFC IDs (one per line)", type: :string
    option :format, desc: "Output format: text (default), html, csv", type: :string, default: "text"
    option :mail, desc: "Comma-separated list of email addresses to send output to", type: :string
    def history(cfc_id = nil)
      require_relative "cfc/commands/history"
      if cfc_id.nil? && options[:ids_file].nil?
        $stderr.puts "Error: Either CFC_ID or --ids-file must be provided"
        $stderr.puts "Usage: cfc history CFC_ID"
        $stderr.puts "       cfc history --ids-file /path/to/ids.txt"
        exit(1)
      end
      if options[:from] && !CLI.valid_date_format?(options[:from])
        $stderr.puts "Error: Invalid date format for --from. Use YYYY-MM-DD or YYYYMMDD (e.g., 2026-01-01 or 20260101)"
        exit(1)
      end
      if options[:to] && !CLI.valid_date_format?(options[:to])
        $stderr.puts "Error: Invalid date format for --to. Use YYYY-MM-DD or YYYYMMDD (e.g., 2026-01-01 or 20260101)"
        exit(1)
      end
      unless %w[text html csv].include?(options[:format])
        $stderr.puts "Error: Invalid format '#{options[:format]}'. Use text, html, or csv"
        exit(1)
      end
      Commands::History.run(cfc_id, from: options[:from], to: options[:to], ids_file: options[:ids_file], format: options[:format], mail: options[:mail])
    end

    desc "show CFC_ID", "Display player information"
    option :ids_file, desc: "File containing CFC IDs (one per line)", type: :string
    option :format, desc: "Output format: text (default), html, csv", type: :string, default: "text"
    option :mail, desc: "Comma-separated list of email addresses to send output to", type: :string
    def show(cfc_id = nil)
      require_relative "cfc/commands/show"
      if cfc_id.nil? && options[:ids_file].nil?
        $stderr.puts "Error: Either CFC_ID or --ids-file must be provided"
        $stderr.puts "Usage: cfc show CFC_ID"
        $stderr.puts "       cfc show --ids-file /path/to/ids.txt"
        exit(1)
      end
      unless %w[text html csv].include?(options[:format])
        $stderr.puts "Error: Invalid format '#{options[:format]}'. Use text, html, or csv"
        exit(1)
      end
      Commands::Show.run(cfc_id, ids_file: options[:ids_file], format: options[:format], mail: options[:mail])
    end

    desc "find", "Search for players by name, province, or city"
    option :last_name, desc: "Family name (supports partial match)", type: :string
    option :first_name, desc: "First name (supports partial match)", type: :string
    option :province, desc: "Province code (e.g., ON, BC)", type: :string
    option :city, desc: "City name (supports partial match)", type: :string
    option :format, desc: "Output format: text (default), html, csv", type: :string, default: "text"
    option :mail, desc: "Comma-separated list of email addresses to send output to", type: :string
    def find
      if options[:last_name].nil? && options[:first_name].nil? &&
         options[:province].nil? && options[:city].nil?
        $stderr.puts "Error: At least one search criterion must be provided"
        $stderr.puts "Usage: cfc find --last_name Smith"
        $stderr.puts "       cfc find --first_name John"
        $stderr.puts "       cfc find --province ON"
        $stderr.puts "       cfc find --city Toronto"
        $stderr.puts "       cfc find --last_name Smith --province ON --city Toronto"
        exit(1)
      end
      unless %w[text html csv].include?(options[:format])
        $stderr.puts "Error: Invalid format '#{options[:format]}'. Use text, html, or csv"
        exit(1)
      end
      require_relative "cfc/commands/find"
      Commands::Find.run(
        last_name: options[:last_name],
        first_name: options[:first_name],
        province: options[:province],
        city: options[:city],
        format: options[:format],
        mail: options[:mail]
      )
    end

    desc "cleanup", "Remove duplicate rating entries (keep oldest when ratings unchanged)"
    def cleanup
      require_relative "cfc/commands/cleanup"
      Commands::Cleanup.run
    end

    def self.exit_on_failure?
      true
    end

    def self.valid_date_format?(date_str)
      return false if date_str.nil? || date_str.empty?

      # Accept YYYY-MM-DD or YYYYMMDD
      return true if date_str =~ /^\d{4}-\d{2}-\d{2}$/
      return true if date_str =~ /^\d{8}$/

      false
    end
  end
end
