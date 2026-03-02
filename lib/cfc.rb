# frozen_string_literal: true

require_relative "cfc/version"
require_relative "cfc/db"
require_relative "cfc/downloader"
require_relative "cfc/diff"

module Cfc
  class Error < StandardError; end

  class Command
    def self.run(args)
      case args.first
      when "download"
        Downloader.download_and_store
      when "diff"
        options = {}
        (0...args.length).step(2) do |i|
          case args[i]
          when "--from"
            options[:from] = args[i + 1]
          when "--to"
            options[:to] = args[i + 1]
          end
        end
        Diff.run(**options)
      else
        puts "Unknown command: #{args.first}"
        puts "Usage:"
        puts "  cfc download"
        puts "  cfc diff [--from DATE] [--to DATE]"
      end
    end
  end
end
