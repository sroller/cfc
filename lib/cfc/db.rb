# frozen_string_literal: true

require "sqlite3"
require "csv"
require "date"
require "net/http"
require "uri"

module Cfc
  class Database
    INSERT_SQL = <<-SQL
      INSERT INTO player_ratings (
        cfc_id, cfc_number, rating, active_rating, fide_rating,
        rating_date, download_date
      ) VALUES (:cfc_id, :cfc_number, :rating, :active_rating, :fide_rating,
                :rating_date, :download_date)
    SQL

    PLAYER_INSERT_SQL = <<-SQL
      INSERT OR REPLACE INTO players (
        cfc_id, cfc_number, last_name, first_name, province, city
      ) VALUES (:cfc_id, :cfc_number, :last_name, :first_name, :province, :city)
    SQL

    BACKUP_DIR = "/var/lib/chess"

    def initialize(db_path = nil)
      @db_path = db_path || File.join(BACKUP_DIR, "cfc_ratings.db")
      @db = SQLite3::Database.new(@db_path)
      @db.results_as_hash = true
      create_tables
    end

    attr_reader :db

    def create_tables
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS player_ratings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cfc_id INTEGER NOT NULL,
          cfc_number TEXT,
          rating INTEGER,
          active_rating INTEGER,
          fide_rating INTEGER,
          rating_date TEXT,
          download_date TEXT NOT NULL
        )
      SQL

      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS players (
          cfc_id INTEGER PRIMARY KEY,
          cfc_number TEXT,
          last_name TEXT,
          first_name TEXT,
          province TEXT,
          city TEXT
        )
      SQL

      @db.execute("CREATE INDEX IF NOT EXISTS idx_cfc_id ON player_ratings(cfc_id)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_rating_date ON player_ratings(rating_date)")
    end

    def clear_data
      @db.execute("DELETE FROM player_ratings")
    end

    def save_players(players, download_date)
      @db.transaction do
        players.each do |player|
          # Save player info
          @db.execute(
            PLAYER_INSERT_SQL,
            cfc_id: player[:cfc_id],
            cfc_number: player[:cfc_number],
            last_name: player[:last_name],
            first_name: player[:first_name],
            province: player[:province],
            city: player[:city]
          )

          # Save rating history (for fixtures: always save; for cached: dedupe)
          @db.execute(
            INSERT_SQL,
            cfc_id: player[:cfc_id],
            cfc_number: player[:cfc_number],
            rating: player[:rating],
            active_rating: player[:active_rating],
            fide_rating: player[:fide_rating],
            rating_date: download_date,
            download_date: download_date
          )
        end
      end
    end

    def get_latest_rating(cfc_id)
      result = @db.execute("SELECT * FROM player_ratings WHERE cfc_id = ? ORDER BY id DESC LIMIT 1", cfc_id)
      result.first
    end

    def rating_changed?(latest, player)
      return true if latest.nil?

      latest_rating = latest["rating"]
      latest_active = latest["active_rating"]
      latest_fide = latest["fide_rating"]

      !(
        latest_rating == player[:rating] &&
        latest_active == player[:active_rating] &&
        latest_fide == player[:fide_rating]
      )
    end

    def get_current_ratings(cfc_ids)
      # Get latest rating for each player
      @db.execute(<<-SQL, cfc_ids)
        SELECT * FROM player_ratings WHERE id IN (
          SELECT MAX(id) FROM player_ratings WHERE cfc_id IN (?) GROUP BY cfc_id
        )
      SQL
    end

    def get_rating_history(cfc_id)
      @db.execute(<<-SQL, cfc_id)
        SELECT rating_date, rating, active_rating, fide_rating
        FROM player_ratings WHERE cfc_id = ?
        ORDER BY rating_date DESC
      SQL
    end

    def close
      @db.close
    end
  end
end