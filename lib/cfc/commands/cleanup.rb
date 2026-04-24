# frozen_string_literal: true

require_relative "../db"

module Cfc
  module Commands
    class Cleanup
      def self.run(db_path: nil)
        db = Database.new(db_path)

        warn "Analyzing rating entries for duplicates..."

        # Get all rating entries ordered by cfc_id and rating_date (oldest first)
        entries = db.db.execute(<<-SQL)
          SELECT id, cfc_id, rating, active_rating, rating_date
          FROM player_ratings
          ORDER BY cfc_id, rating_date ASC, id ASC
        SQL

        warn "Total entries: #{entries.length}"

        duplicates = []
        last_key = nil

        entries.each do |entry|
          # Create a key based on cfc_id and ratings (excluding date)
          key = [
            entry["cfc_id"],
            entry["rating"],
            entry["active_rating"]
          ]

          if key == last_key
            # This is a duplicate - same player with same ratings
            duplicates << entry["id"]
          else
            # New unique entry
            last_key = key
          end
        end

        if duplicates.empty?
          warn "No duplicates found. Database is clean!"
          db.close
          return
        end

        warn "Found #{duplicates.length} duplicate entries to remove"
        warn "Keeping #{entries.length - duplicates.length} unique entries"

        # Delete duplicates in batches (SQLite has parameter limit)
        batch_size = 900
        deleted_count = 0

        duplicates.each_slice(batch_size) do |batch|
          placeholders = batch.map { "?" }.join(",")
          db.db.execute(<<-SQL, batch)
            DELETE FROM player_ratings WHERE id IN (#{placeholders})
          SQL
          deleted_count += batch.length
          warn "Progress: #{deleted_count}/#{duplicates.length} deleted..."
        end

        warn "Cleanup complete!"
        warn "Removed #{deleted_count} duplicate entries"

        db.close
      end
    end
  end
end
