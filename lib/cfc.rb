# frozen_string_literal: true

require_relative "cfc/version"
require_relative "cfc/db"
require_relative "cfc/downloader"
require_relative "cfc/diff"
require_relative "cfc/helpers"
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
      validate_mutually_exclusive!(:ids, :ids_file)
      validate_dates!(:from, :to)
      validate_format!
      Diff.run(from: options[:from], to: options[:to], ids: options[:ids], ids_file: options[:ids_file],
               format: options[:format], mail: options[:mail])
    end

    desc "history CFC_ID", "Show rating history for a player"
    option :from, desc: "Start date (YYYY-MM-DD or YYYYMMDD)", type: :string
    option :to, desc: "End date (YYYY-MM-DD or YYYYMMDD)", type: :string
    option :ids_file, desc: "File containing CFC IDs (one per line)", type: :string
    option :format, desc: "Output format: text (default), html, csv", type: :string, default: "text"
    option :mail, desc: "Comma-separated list of email addresses to send output to", type: :string
    def history(cfc_id = nil)
      require_relative "cfc/commands/history"
      require_id_or_file!(cfc_id, "history")
      validate_dates!(:from, :to)
      validate_format!
      Commands::History.run(cfc_id, from: options[:from], to: options[:to], ids_file: options[:ids_file],
                                    format: options[:format], mail: options[:mail])
    end

    desc "show CFC_ID", "Display player information"
    option :ids_file, desc: "File containing CFC IDs (one per line)", type: :string
    option :format, desc: "Output format: text (default), html, csv", type: :string, default: "text"
    option :mail, desc: "Comma-separated list of email addresses to send output to", type: :string
    def show(cfc_id = nil)
      require_relative "cfc/commands/show"
      require_id_or_file!(cfc_id, "show")
      validate_format!
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
      if %i[last_name first_name province city].all? { |k| options[k].nil? }
        abort "Error: At least one search criterion must be provided\n" \
              "Usage: cfc find --last_name Smith\n" \
              "       cfc find --first_name John\n" \
              "       cfc find --province ON\n" \
              "       cfc find --city Toronto"
      end
      validate_format!
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

    desc "ids SUBCOMMAND FILEPATH", "Manage IDs files (list, add, remove, validate)"
    option :name, desc: "Custom name for add subcommand", type: :string
    def ids(subcommand = nil, filepath = nil, *args)
      require_relative "cfc/commands/ids"
      require "fileutils"

      unless subcommand && filepath
        abort "Error: Subcommand and filepath are required\n" \
              "Usage: cfc ids list FILEPATH\n" \
              "       cfc ids add FILEPATH CFC_ID [--name NAME]\n" \
              "       cfc ids remove FILEPATH CFC_ID\n" \
              "       cfc ids validate FILEPATH"
      end

      case subcommand
      when "list"
        Commands::Ids.list(filepath)
      when "add"
        abort "Error: CFC ID is required for add subcommand" unless args.first
        Commands::Ids.add(filepath, args.first, options[:name])
      when "remove"
        abort "Error: CFC ID is required for remove subcommand" unless args.first
        Commands::Ids.remove(filepath, args.first)
      when "validate"
        Commands::Ids.validate(filepath)
      else
        abort "Error: Unknown subcommand '#{subcommand}'\nAvailable subcommands: list, add, remove, validate"
      end
    end

    desc "cleanup", "Remove duplicate rating entries (keep oldest when ratings unchanged)"
    def cleanup
      require_relative "cfc/commands/cleanup"
      Commands::Cleanup.run
    end

    def self.exit_on_failure?
      true
    end

    private

    def validate_format!
      return if %w[text html csv].include?(options[:format])

      abort "Error: Invalid format '#{options[:format]}'. Use text, html, or csv"
    end

    def validate_dates!(*keys)
      keys.each do |key|
        next unless options[key]
        next if Helpers.valid_date_format?(options[key])

        abort "Error: Invalid date format for --#{key}. Use YYYY-MM-DD or YYYYMMDD (e.g., 2026-01-01 or 20260101)"
      end
    end

    def validate_mutually_exclusive!(*keys)
      provided = keys.select { |k| options[k] }
      return if provided.length <= 1

      abort "Error: Cannot use both --#{provided[0]} and --#{provided[1]} options"
    end

    def require_id_or_file!(cfc_id, command)
      return if cfc_id || options[:ids_file]

      abort "Error: Either CFC_ID or --ids-file must be provided\n" \
            "Usage: cfc #{command} CFC_ID\n" \
            "       cfc #{command} --ids-file /path/to/ids.txt"
    end
  end
end
