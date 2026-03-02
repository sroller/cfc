# frozen_string_literal: true

require "sqlite3"
require "csv"
require "date"
require "net/http"
require "uri"

module Cfc
  class Database
    INSERT_SQL = <<-SQL
      INSERT INTO players (
        cfc_id, cfc_number, expiry, last_name, first_name,
        province, city, rating, high_rating, active_rating,
        active_high_rating, fide_number, fide_rating, download_date
      ) VALUES (:cfc_id, :cfc_number, :expiry, :last_name, :first_name,
                :province, :city, :rating, :high_rating, :active_rating,
                :active_high_rating, :fide_number, :fide_rating, :download_date)
    SQL

    def initialize(db_path = "cfc_ratings.db")
      @db_path = db_path
      @db = SQLite3::Database.new(db_path)
      @db.results_as_hash = true
      create_table
    end

    attr_reader :db

    def create_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS players (
          cfc_id INTEGER PRIMARY KEY,
          cfc_number TEXT,
          expiry DATE,
          last_name TEXT,
          first_name TEXT,
          province TEXT,
          city TEXT,
          rating INTEGER,
          high_rating INTEGER,
          active_rating INTEGER,
          active_high_rating INTEGER,
          fide_number TEXT,
          fide_rating INTEGER,
          download_date DATE NOT NULL
        )
      SQL
    end

    def clear_data
      @db.execute("DELETE FROM players")
    end

    def save_players(players, download_date)
      @db.transaction do
        players.each do |player|
          @db.execute(
            INSERT_SQL,
            cfc_id: player[:cfc_id],
            cfc_number: player[:cfc_number],
            expiry: player[:expiry],
            last_name: player[:last_name],
            first_name: player[:first_name],
            province: player[:province],
            city: player[:city],
            rating: player[:rating],
            high_rating: player[:high_rating],
            active_rating: player[:active_rating],
            active_high_rating: player[:active_high_rating],
            fide_number: player[:fide_number],
            fide_rating: player[:fide_rating],
            download_date: download_date
          )
        end
      end
    end

    def close
      @db.close
    end
  end
end