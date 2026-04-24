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
        cfc_id, rating, active_rating,
        rating_date, download_date
      ) VALUES (:cfc_id, :rating, :active_rating,
                :rating_date, :download_date)
    SQL

    PLAYER_INSERT_SQL = <<-SQL
      INSERT OR REPLACE INTO players (
        cfc_id, last_name, first_name, province, city, expire_date
      ) VALUES (:cfc_id, :last_name, :first_name, :province, :city, :expire_date)
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
          rating INTEGER,
          active_rating INTEGER,
          rating_date TEXT,
          download_date TEXT NOT NULL
        )
      SQL

      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS players (
          cfc_id INTEGER PRIMARY KEY,
          last_name TEXT,
          first_name TEXT,
          province TEXT,
          city TEXT,
          expire_date TEXT
        )
      SQL

      @db.execute("CREATE INDEX IF NOT EXISTS idx_cfc_id ON player_ratings(cfc_id)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_rating_date ON player_ratings(rating_date)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_players_last_name ON players(last_name COLLATE NOCASE)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_players_first_name ON players(first_name COLLATE NOCASE)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_players_name ON players(last_name COLLATE NOCASE, first_name COLLATE NOCASE)")
    end

    def clear_data
      @db.execute("DELETE FROM player_ratings")
      @db.execute("DELETE FROM players")
    end

    def save_players(players, download_date, dedupe: true)
      @db.transaction do
        players.each do |player|
          # Save player info
          @db.execute(
            PLAYER_INSERT_SQL,
            cfc_id: player[:cfc_id],
            last_name: player[:last_name],
            first_name: player[:first_name],
            province: player[:province],
            city: player[:city],
            expire_date: player[:expire_date]
          )

          # Save rating history (with deduplication if enabled)
          next unless !dedupe || rating_changed?(player[:cfc_id], player)

          @db.execute(
            INSERT_SQL,
            cfc_id: player[:cfc_id],
            rating: player[:rating],
            active_rating: player[:active_rating],
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

    def rating_changed?(cfc_id, player)
      latest = get_latest_rating(cfc_id)
      return true if latest.nil?

      latest_rating = latest["rating"]
      latest_active = latest["active_rating"]

      !(
        latest_rating == player[:rating] &&
        latest_active == player[:active_rating]
      )
    end

    def get_current_ratings(cfc_ids)
      # Get latest rating for each player
      # Build placeholders for the IN clause
      placeholders = cfc_ids.map { "?" }.join(",")
      sql = <<-SQL
        SELECT * FROM player_ratings WHERE id IN (
          SELECT MAX(id) FROM player_ratings WHERE cfc_id IN (#{placeholders}) GROUP BY cfc_id
        )
      SQL
      @db.execute(sql, cfc_ids)
    end

    def get_rating_history(cfc_id)
      @db.execute(<<-SQL, cfc_id)
        SELECT rating_date, rating, active_rating
        FROM player_ratings WHERE cfc_id = ?
        ORDER BY rating_date DESC
      SQL
    end

    def get_rating_history_by_date(date)
      @db.execute(<<-SQL, date)
        SELECT cfc_id, rating, active_rating
        FROM player_ratings WHERE rating_date = ?
      SQL
    end

    def get_rating_history_by_date_with_player_info(date)
      # Get the latest rating for each player AS OF the given date (not exact match)
      @db.execute(<<-SQL, date)
        SELECT pr.cfc_id, pr.rating, pr.active_rating, p.expire_date,
               p.first_name, p.last_name, p.province, p.city
        FROM player_ratings pr
        JOIN players p ON pr.cfc_id = p.cfc_id
        WHERE pr.id IN (
          SELECT MAX(pr2.id) FROM player_ratings pr2
          WHERE pr2.rating_date <= ?
          GROUP BY pr2.cfc_id
        )
      SQL
    end

    def get_player(cfc_id)
      result = @db.execute(<<-SQL, cfc_id)
        SELECT p.cfc_id, p.last_name, p.first_name, p.province, p.city, p.expire_date,
               r.rating, r.active_rating, r.rating_date
        FROM players p
        LEFT JOIN player_ratings r ON p.cfc_id = r.cfc_id
        WHERE p.cfc_id = ?
        ORDER BY r.rating_date DESC
        LIMIT 1
      SQL
      result.first
    end

    def get_player_history(cfc_id, from_date: nil, to_date: nil)
      sql = <<-SQL
        SELECT rating_date, rating, active_rating
        FROM player_ratings
        WHERE cfc_id = ?
      SQL
      params = [cfc_id]

      if from_date
        sql += " AND rating_date >= ?"
        params << from_date
      end

      if to_date
        sql += " AND rating_date <= ?"
        params << to_date
      end

      sql += " ORDER BY rating_date DESC"

      @db.execute(sql, params)
    end

    def find_players(last_name: nil, first_name: nil, province: nil, city: nil)
      sql = <<-SQL
        SELECT p.cfc_id, p.last_name, p.first_name, p.province, p.city, p.expire_date,
               r.rating, r.active_rating, r.rating_date
        FROM players p
        LEFT JOIN player_ratings r ON p.cfc_id = r.cfc_id
        WHERE r.id = (SELECT MAX(id) FROM player_ratings WHERE cfc_id = p.cfc_id)
      SQL
      params = []

      if last_name
        sql += " AND p.last_name LIKE ?"
        params << "%#{last_name}%"
      end

      if first_name
        sql += " AND p.first_name LIKE ?"
        params << "%#{first_name}%"
      end

      if province
        sql += " AND p.province LIKE ?"
        params << "%#{province}%"
      end

      if city
        sql += " AND p.city LIKE ?"
        params << "%#{city}%"
      end

      sql += " ORDER BY p.last_name, p.first_name"

      @db.execute(sql, params)
    end

    def search_by_name(query)
      terms = query.strip.split(/\s+/)
      return [] if terms.empty?

      if terms.length == 1
        term = terms.first
        @db.execute(<<-SQL, ["%#{term}%", "%#{term}%"])
          SELECT p.cfc_id, p.last_name, p.first_name, p.province, p.city, p.expire_date,
                 r.rating, r.active_rating, r.rating_date
          FROM players p
          LEFT JOIN player_ratings r ON p.cfc_id = r.cfc_id
          WHERE r.id = (SELECT MAX(id) FROM player_ratings WHERE cfc_id = p.cfc_id)
            AND (p.last_name LIKE ? COLLATE NOCASE OR p.first_name LIKE ? COLLATE NOCASE)
          ORDER BY p.last_name COLLATE NOCASE, p.first_name COLLATE NOCASE
          LIMIT 50
        SQL
      else
        # Try both "first last" and "last first" orderings
        first = terms[0]
        last = terms[1..].join(" ")
        @db.execute(<<-SQL, ["%#{first}%", "%#{last}%", "%#{last}%", "%#{first}%"])
          SELECT p.cfc_id, p.last_name, p.first_name, p.province, p.city, p.expire_date,
                 r.rating, r.active_rating, r.rating_date
          FROM players p
          LEFT JOIN player_ratings r ON p.cfc_id = r.cfc_id
          WHERE r.id = (SELECT MAX(id) FROM player_ratings WHERE cfc_id = p.cfc_id)
            AND ((p.first_name LIKE ? COLLATE NOCASE AND p.last_name LIKE ? COLLATE NOCASE)
              OR (p.first_name LIKE ? COLLATE NOCASE AND p.last_name LIKE ? COLLATE NOCASE))
          ORDER BY p.last_name COLLATE NOCASE, p.first_name COLLATE NOCASE
          LIMIT 50
        SQL
      end
    end

    def close
      @db.close
    end
  end
end
