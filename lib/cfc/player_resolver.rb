# frozen_string_literal: true

require_relative "db"
require_relative "helpers"

module Cfc
  module PlayerResolver
    # Resolve a player identifier (CFC ID or name) to an array of CFC IDs.
    # When multiple matches are found and stdin is a TTY, presents an interactive prompt.
    # @param identifier [String, Integer] CFC ID or player name
    # @param db [Database] open database connection
    # @param multi [Boolean] allow selecting multiple players (default: false)
    # @return [Array<Integer>] resolved CFC IDs
    def self.resolve(identifier, db:, multi: false)
      if numeric?(identifier)
        [Integer(identifier)]
      else
        resolve_by_name(identifier, db: db, multi: multi)
      end
    end

    # Check if a string looks like a numeric CFC ID
    def self.numeric?(str)
      str.is_a?(Integer) || (str.is_a?(String) && str.match?(/\A\d+\z/))
    end

    def self.resolve_by_name(name, db:, multi: false)
      players = db.search_by_name(name)

      if players.empty?
        abort "Error: No players found matching '#{name}'"
      elsif players.length == 1
        [players.first["cfc_id"]]
      elsif !$stdin.tty?
        abort "Error: Multiple players match '#{name}'. Use a CFC ID or run interactively:\n" \
              "#{format_player_list(players)}"
      else
        interactive_select(players, name, multi: multi)
      end
    end

    def self.interactive_select(players, query, multi: false)
      require "tty-prompt"
      prompt = TTY::Prompt.new

      choices = players.map do |p|
        label = format_player_choice(p)
        { name: label, value: p["cfc_id"] }
      end

      if multi
        selected = prompt.multi_select("Multiple players match '#{query}'. Select one or more:",
                                       choices, per_page: 15, min: 1)
      else
        selected = prompt.select("Multiple players match '#{query}'. Select one:",
                                 choices, per_page: 15)
        selected = [selected]
      end

      selected
    end

    def self.format_player_choice(player)
      last = player["last_name"] || ""
      first = player["first_name"] || ""
      name = "#{last}, #{first}".strip.chomp(",")
      location = Helpers.format_location(player["city"], player["province"])
      location_str = location.empty? ? "" : " (#{location})"
      rating = player["rating"] || 0
      "#{player["cfc_id"]} #{name}#{location_str} - Rating: #{rating}"
    end

    def self.format_player_list(players)
      players.map { |p| "  #{format_player_choice(p)}" }.join("\n")
    end
  end
end
