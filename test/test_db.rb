# frozen_string_literal: true

require "test_helper"
require "cfc/db"
require "tmpdir"

class TestDb < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_create_table
    result = @db.db.execute("SELECT COUNT(*) FROM players")
    assert_equal(0, result.first&.[]("COUNT(*)") || 0)
  end

  def test_save_and_retrieve_players
    players = [
      {
        cfc_id: 100_001,
        expiry: "2025-12-18",
        last_name: "Roller",
        first_name: "John",
        province: "ON",
        city: "Toronto",
        rating: 1500,
        high_rating: 1600,
        active_rating: 1500,
        active_high_rating: 1600,
        fide_number: "123456",
        fide_rating: 1500
      },
      {
        cfc_id: 100_002,
        expiry: "2025-12-18",
        last_name: "Smith",
        first_name: "Jane",
        province: "BC",
        city: "Vancouver",
        rating: 1800,
        high_rating: 1900,
        active_rating: 1800,
        active_high_rating: 1900,
        fide_number: "789012",
        fide_rating: 1800
      }
    ]

    @db.save_players(players, "2026-03-01")

    result = @db.db.execute("SELECT COUNT(*) FROM players")
    assert_equal(2, result.first&.[]("COUNT(*)") || 0)

    roller_players = @db.db.execute(
      "SELECT * FROM players WHERE last_name = 'Roller'"
    )
    assert_equal(1, roller_players.length)
    assert_equal("John", roller_players.first&.[]("first_name") || roller_players[0][4])

    smith_players = @db.db.execute(
      "SELECT * FROM players WHERE city = 'Vancouver'"
    )
    assert_equal(1, smith_players.length)
  end

  def test_clear_data
    players = [
      {
        cfc_id: 100_001,
        expiry: nil,
        last_name: "Test",
        first_name: "User",
        province: "ON",
        city: "Toronto",
        rating: 1500,
        high_rating: 1600,
        active_rating: 1500,
        active_high_rating: 1600,
        fide_number: nil,
        fide_rating: nil
      }
    ]

    @db.save_players(players, "2026-03-01")

    @db.clear_data

    result = @db.db.execute("SELECT COUNT(*) FROM players")
    assert_equal(0, result.first&.[]("COUNT(*)") || 0)
  end
end
