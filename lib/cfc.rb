# frozen_string_literal: true

require_relative "cfc/version"
require_relative "cfc/db"
require_relative "cfc/downloader"
require_relative "cfc/diff"
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
    option :from, desc: "Start date (YYYYMMDD)", type: :string
    option :to, desc: "End date (YYYYMMDD)", type: :string
    option :ids, desc: "Comma-separated list of CFC IDs to filter", type: :string
    option :ids_file, desc: "File containing CFC IDs (one per line)", type: :string
    def diff
      if options[:ids] && options[:ids_file]
        puts "Error: Cannot use both --ids and --ids_file options"
        exit(1)
      end
      Diff.run(from: options[:from], to: options[:to], ids: options[:ids], ids_file: options[:ids_file])
    end

    desc "history CFC_ID", "Show rating history for a player"
    option :from, desc: "Start date (YYYYMMDD)", type: :string
    option :to, desc: "End date (YYYYMMDD)", type: :string
    option :ids_file, desc: "File containing CFC IDs (one per line)", type: :string
    def history(cfc_id = nil)
      require_relative "cfc/commands/history"
      if cfc_id.nil? && options[:ids_file].nil?
        puts "Error: Either CFC_ID or --ids-file must be provided"
        puts "Usage: cfc history CFC_ID"
        puts "       cfc history --ids-file /path/to/ids.txt"
        exit(1)
      end
      Commands::History.run(cfc_id, from: options[:from], to: options[:to], ids_file: options[:ids_file])
    end

    desc "show CFC_ID", "Display player information"
    option :ids_file, desc: "File containing CFC IDs (one per line)", type: :string
    def show(cfc_id = nil)
      require_relative "cfc/commands/show"
      if cfc_id.nil? && options[:ids_file].nil?
        puts "Error: Either CFC_ID or --ids-file must be provided"
        puts "Usage: cfc show CFC_ID"
        puts "       cfc show --ids-file /path/to/ids.txt"
        exit(1)
      end
      Commands::Show.run(cfc_id, ids_file: options[:ids_file])
    end

    desc "find", "Search for players by name, province, or city"
    option :last_name, desc: "Family name (supports partial match)", type: :string
    option :first_name, desc: "First name (supports partial match)", type: :string
    option :province, desc: "Province code (e.g., ON, BC)", type: :string
    option :city, desc: "City name (supports partial match)", type: :string
    def find
      if options[:last_name].nil? && options[:first_name].nil? &&
         options[:province].nil? && options[:city].nil?
        puts "Error: At least one search criterion must be provided"
        puts "Usage: cfc find --last_name Smith"
        puts "       cfc find --first_name John"
        puts "       cfc find --province ON"
        puts "       cfc find --city Toronto"
        puts "       cfc find --last_name Smith --province ON --city Toronto"
        exit(1)
      end
      require_relative "cfc/commands/find"
      Commands::Find.run(
        last_name: options[:last_name],
        first_name: options[:first_name],
        province: options[:province],
        city: options[:city]
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
  end
end
