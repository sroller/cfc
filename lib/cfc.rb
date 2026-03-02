# frozen_string_literal: true

require_relative "cfc/version"
require_relative "cfc/db"
require_relative "cfc/downloader"

module Cfc
  class Error < StandardError; end

  class Command
    def self.run(args)
      case args.first
      when "download"
        Downloader.download_and_store
      else
        puts "Unknown command: #{args.first}"
        puts "Usage: cfc download"
      end
    end
  end
end
