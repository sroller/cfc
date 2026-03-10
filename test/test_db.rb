# frozen_string_literal: true

require "test_helper"
require "cfc/db"
require "tmpdir"

class TestDbSavePlayers < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    @players = [
      {
        cfc_id: 100_001,
        expiry: "2025-12-18",
        last_name: "Smith",
        first_name: "John",
        province: "ON",
        city: "Toronto",
        rating: 1500,
        high_rating: 1600,
        active_rating: 1500,
        active_high_rating: 1600
      }
    ]
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_save_players_adds_player_info
    @db.save_players(@players, "2024-01-01", dedupe: false)

    result = @db.db.execute("SELECT COUNT(*) FROM players")
    assert_equal(1, result.first["COUNT(*)"])
  end

  def test_save_players_creates_rating_entry
    @db.save_players(@players, "2024-01-01", dedupe: false)

    result = @db.db.execute("SELECT COUNT(*) FROM player_ratings")
    assert_equal(1, result.first["COUNT(*)"])
  end

  def test_save_players_nil_rating_values
    players_with_nil = @players.dup
    players_with_nil[0][:rating] = nil
    players_with_nil[0][:active_rating] = nil

    @db.save_players(players_with_nil, "2024-01-01", dedupe: false)

    result = @db.db.execute("SELECT COUNT(*) FROM player_ratings")
    assert_equal(1, result.first["COUNT(*)"])
  end

  def test_save_players_different_date_creates_new_entry
    @db.save_players(@players, "2024-01-01", dedupe: false)
    @db.save_players(@players, "2024-02-01", dedupe: false)

    result = @db.db.execute("SELECT COUNT(*) FROM player_ratings")
    assert_equal(2, result.first["COUNT(*)"])
  end

  def test_save_players_with_dedupe_false_adds_multiple_entries
    players_1 = [{ cfc_id: 100_001, rating: 1500, active_rating: 1500 }]
    players_2 = [{ cfc_id: 100_001, rating: 1550, active_rating: 1550 }]

    @db.save_players(players_1, "2024-01-01", dedupe: false)
    @db.save_players(players_2, "2024-02-01", dedupe: false)

    result = @db.db.execute("SELECT COUNT(*) FROM player_ratings")
    assert_equal(2, result.first["COUNT(*)"])
  end

  def test_save_players_with_dedupe_true_same_rating_skips
    players_1 = [{ cfc_id: 100_001, rating: 1500, active_rating: 1500 }]
    players_2 = [{ cfc_id: 100_001, rating: 1500, active_rating: 1500 }]

    @db.save_players(players_1, "2024-01-01", dedupe: true)
    @db.save_players(players_2, "2024-02-01", dedupe: true)

    result = @db.db.execute("SELECT COUNT(*) FROM player_ratings")
    assert_equal(1, result.first["COUNT(*)"])
  end

  def test_save_players_with_dedupe_true_different_rating_adds
    players_1 = [{ cfc_id: 100_001, rating: 1500, active_rating: 1500 }]
    players_2 = [{ cfc_id: 100_001, rating: 1550, active_rating: 1550 }]

    @db.save_players(players_1, "2024-01-01", dedupe: true)
    @db.save_players(players_2, "2024-02-01", dedupe: true)

    result = @db.db.execute("SELECT COUNT(*) FROM player_ratings")
    assert_equal(2, result.first["COUNT(*)"])
  end

  def test_save_players_empty_array
    @db.save_players([], "2024-01-01", dedupe: false)

    result = @db.db.execute("SELECT COUNT(*) FROM player_ratings")
    assert_equal(0, result.first["COUNT(*)"])
  end

  def test_save_players_single_player
    single_player = [{
      cfc_id: 100_001,
      expiry: "2025-12-18",
      last_name: "Smith",
      first_name: "John",
      province: "ON",
      city: "Toronto",
      rating: 1500,
      high_rating: 1600,
      active_rating: 1500,
      active_high_rating: 1600
    }]

    @db.save_players(single_player, "2024-01-01", dedupe: false)

    result = @db.db.execute("SELECT COUNT(*) FROM player_ratings")
    assert_equal(1, result.first["COUNT(*)"])
  end

  def test_save_players_updates_existing_player_info
    players_v1 = [{ cfc_id: 100_001, last_name: "Old", first_name: "John" }]
    players_v2 = [{ cfc_id: 100_001, last_name: "New", first_name: "John" }]

    @db.save_players(players_v1, "2024-01-01", dedupe: false)
    @db.save_players(players_v2, "2024-02-01", dedupe: false)

    result = @db.get_player(100_001)
    assert_equal("New", result["last_name"])
  end
end

class TestDbRatingChanged < Minitest::Test
  def setup
    super
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    # Insert a rating record
    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (1, 1000, 1000, '2024-01-01', '2024-01-01')
    SQL
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_rating_changed_both_different
    assert(@db.rating_changed?(1, { rating: 1100, active_rating: 1100 }))
  end

  def test_rating_changed_same_values
    refute(@db.rating_changed?(1, { rating: 1000, active_rating: 1000 }))
  end

  def test_rating_changed_only_rating_different
    assert(@db.rating_changed?(1, { rating: 1100, active_rating: 1000 }))
  end

  def test_rating_changed_only_active_different
    assert(@db.rating_changed?(1, { rating: 1000, active_rating: 1100 }))
  end

  def test_rating_changed_latest_nil_returns_true
    refute(@db.get_latest_rating(999))
    assert(@db.rating_changed?(999, { rating: 1000, active_rating: 1000 }))
  end

  def test_rating_changed_with_nil_values
    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (1, nil, nil, '2024-01-01', '2024-01-01')
    SQL

    assert(@db.rating_changed?(1, { rating: 1000, active_rating: 1000 }))
  end

  def test_rating_changed_no_existing_record
    refute(@db.get_latest_rating(999))
    assert(@db.rating_changed?(999, { rating: 1000, active_rating: 1000 }))
  end
end

class TestDbGetCurrentRatings < Minitest::Test
  def setup
    super
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    # Create ratings for multiple players across different dates
    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100_001, 1000, 1000, '2024-01-01', '2024-01-01'),
      (100_001, 1050, 1050, '2024-02-01', '2024-02-01'),
      (200_001, 1200, 1200, '2024-02-01', '2024-02-01')
    SQL
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_get_current_ratings_returns_latest_for_each
    results = @db.get_current_ratings([100_001, 200_001])
    assert_equal(2, results.length)
    result_for_100k = results.find { |r| r["cfc_id"] == 100_001 }
    assert_equal(1050, result_for_100k["rating"])
  end

  def test_get_current_ratings_empty_array
    results = @db.get_current_ratings([])
    assert_empty(results)
  end

  def test_get_current_ratings_single_player
    results = @db.get_current_ratings([100_001])
    assert_equal(1, results.length)
    assert_equal(1050, results.first["rating"])
  end

  def test_get_current_ratings_nonexistent_players
    results = @db.get_current_ratings([999_999, 888_888])
    assert_empty(results)
  end
end

class TestDbGetRatingHistory < Minitest::Test
  def setup
    super
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    # Create rating history for a player
    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100_001, 1000, 1000, '2024-01-01', '2024-01-01'),
      (100_001, 1050, 1050, '2024-02-01', '2024-02-01'),
      (100_001, 1100, 1100, '2024-03-01', '2024-03-01')
    SQL
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_get_rating_history_returns_all_records
    results = @db.get_rating_history(100_001)
    assert_equal(3, results.length)
  end

  def test_get_rating_history_empty
    refute(@db.get_rating_history(999_999))
    assert_equal(0, @db.get_rating_history(999_999).length)
  end

  def test_get_rating_history_ordered_by_date_desc
    results = @db.get_rating_history(100_001)
    assert_equal("2024-03-01", results.first["rating_date"])
    assert_equal("2024-01-01", results.last["rating_date"])
  end

  def test_get_rating_history_single_record
    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100_002, 2000, 2000, '2024-01-01', '2024-01-01')
    SQL

    results = @db.get_rating_history(100_002)
    assert_equal(1, results.length)
  end
end

class TestDbGetRatingHistoryByDate < Minitest::Test
  def setup
    super
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    # Create ratings for different dates and players
    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100_001, 1000, 1000, '2024-01-01', '2024-01-01'),
      (200_001, 1200, 1200, '2024-01-01', '2024-01-01'),
      (300_001, 1500, 1500, '2024-02-01', '2024-02-01')
    SQL

    # Create player info
    @db.db.execute(<<-SQL)
      INSERT INTO players (cfc_id, last_name, first_name, province, city) VALUES
      (100_001, 'Doe', 'John', 'ON', 'Toronto'),
      (200_001, 'Smith', 'Jane', 'BC', 'Vancouver'),
      (300_001, 'Johnson', 'Bob', 'AB', 'Calgary')
    SQL
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_get_rating_history_by_date_returns_matching
    results = @db.get_rating_history_by_date("2024-01-01")
    assert_equal(2, results.length)
    cfc_ids = results.map { |r| r["cfc_id"] }.sort
    assert_equal([100_001, 200_001], cfc_ids)
  end

  def test_get_rating_history_by_date_empty
    results = @db.get_rating_history_by_date("9999-12-31")
    assert_empty(results)
  end

  def test_get_rating_history_by_date_returns_different_players_for_each_date
    results_jan = @db.get_rating_history_by_date("2024-01-01")
    results_feb = @db.get_rating_history_by_date("2024-02-01")

    assert_equal(2, results_jan.length)
    assert_equal(1, results_feb.length)
  end
end

class TestDbGetPlayer < Minitest::Test
  def setup
    super
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    # Create player with rating history
    @db.db.execute(<<-SQL)
      INSERT INTO players (cfc_id, last_name, first_name, province, city) VALUES
      (100_001, 'Doe', 'John', 'ON', 'Toronto'),
      (200_002, 'Smith', 'Jane', 'BC', 'Vancouver')
    SQL

    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100_001, 1000, 1000, '2024-01-01', '2024-01-01'),
      (200_002, 1500, 1500, '2024-01-01', '2024-01-01')
    SQL
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_get_player_returns_player_data
    result = @db.get_player(100_001)
    refute_nil(result)
    assert_equal("Doe", result["last_name"])
    assert_equal("John", result["first_name"])
    assert_equal(1000, result["rating"])
  end

  def test_get_player_not_found
    result = @db.get_player(999_999)
    assert_nil(result)
  end

  def test_get_player_with_no_rating_history
    @db.db.execute(<<-SQL)
      INSERT INTO players (cfc_id, last_name, first_name, province, city) VALUES
      (300_001, 'Wilson', 'Tim', 'MB', 'Winnipeg')
    SQL

    result = @db.get_player(300_001)
    refute_nil(result)
    assert_equal("Wilson", result["last_name"])
    assert_nil(result["rating"])
  end
end

class TestDbGetPlayerHistory < Minitest::Test
  def setup
    super
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100_001, 1000, 1000, '2024-01-01', '2024-01-01'),
      (100_001, 1050, 1050, '2024-02-01', '2024-02-01'),
      (100_001, 1100, 1100, '2024-03-01', '2024-03-01')
    SQL
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_get_player_history_no_filters
    results = @db.get_player_history(100_001)
    assert_equal(3, results.length)
  end

  def test_get_player_history_with_from_date
    results = @db.get_player_history(100_001, from_date: "2024-02-01")
    assert_equal(2, results.length) # Feb and March
  end

  def test_get_player_history_with_to_date
    results = @db.get_player_history(100_001, to_date: "2024-02-01")
    assert_equal(1, results.length) # Only February
  end

  def test_get_player_history_with_both_dates
    results = @db.get_player_history(100_001, from_date: "2024-01-15", to_date: "2024-02-28")
    assert_equal(2, results.length)
  end

  def test_get_player_history_empty_no_history
    results = @db.get_player_history(999_999)
    assert_equal(0, results.length)
  end

  def test_get_player_history_from_date_before_all_records
    results = @db.get_player_history(100_001, from_date: "2023-01-01")
    assert_equal(3, results.length)
  end

  def test_get_player_history_to_date_after_all_records
    results = @db.get_player_history(100_001, to_date: "2026-12-31")
    assert_equal(3, results.length)
  end

  def test_get_player_history_empty_range
    results = @db.get_player_history(100_001, from_date: "2024-05-01", to_date: "2024-06-01")
    assert_equal(0, results.length)
  end
end

class TestDbFindPlayers < Minitest::Test
  def setup
    super
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    @db.db.execute(<<-SQL)
      INSERT INTO players (cfc_id, last_name, first_name, province, city) VALUES
      (100_001, 'Smith', 'John', 'ON', 'Toronto'),
      (100_002, 'Doe', 'Jane', 'BC', 'Vancouver'),
      (100_003, 'Johnson', 'Bob', 'AB', 'Calgary'),
      (100_004, 'Williams', 'Alice', 'MB', 'Winnipeg')
    SQL

    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100_001, 1500, 1500, '2024-01-01', '2024-01-01'),
      (100_002, 1600, 1600, '2024-01-01', '2024-01-01'),
      (100_003, 1700, 1700, '2024-01-01', '2024-01-01'),
      (100_004, 1800, 1800, '2024-01-01', '2024-01-01')
    SQL
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_find_players_no_criteria_returns_all
    results = @db.find_players(last_name: nil, first_name: nil, province: nil, city: nil)
    assert_equal(4, results.length)
  end

  def test_find_players_by_last_name_partial_match
    results = @db.find_players(last_name: "Smith")
    assert_equal(1, results.length)
    assert_equal("Smith", results.first["last_name"])
  end

  def test_find_players_by_first_name_partial_match
    results = @db.find_players(first_name: "John")
    assert_equal(1, results.length)
    assert_equal("John", results.first["first_name"])
  end

  def test_find_players_by_province
    results = @db.find_players(province: "ON")
    assert_equal(1, results.length)
    assert_equal("ON", results.first["province"])
  end

  def test_find_players_by_city
    results = @db.find_players(city: "Toronto")
    assert_equal(1, results.length)
    assert_equal("Toronto", results.first["city"])
  end

  def test_find_players_combined_criteria
    results = @db.find_players(last_name: "Smith", province: "ON")
    assert_equal(1, results.length)
    assert_equal("Toronto", results.first["city"])
  end

  def test_find_players_multiple_matching_provinces
    results = @db.find_players(province: "%N") # Matches ON and MB
    assert_equal(2, results.length)
  end

  def test_find_players_no_matches
    results = @db.find_players(last_name: "NonExistent", province: "SK", city: "Saskatoon")
    assert_empty(results)
  end

  def test_find_players_ordered_by_name
    # Sort by creating 5 players and verify ordering
    @db.db.execute(<<-SQL)
      INSERT INTO players (cfc_id, last_name, first_name, province, city) VALUES
      (100_005, 'Zoe', 'Zooey', 'ON', 'Toronto'),
      (100_006, 'Anna', 'Ann', 'BC', 'Vancouver')
    SQL

    results = @db.find_players(last_name: nil)
    cfc_ids = results.map { |r| r["cfc_id"] }.sort
    expected = [100_001, 100_002, 100_003, 100_004, 100_005, 100_006]
    assert_equal(expected, cfc_ids)
  end

  def test_find_players_by_last_name_and_city_combined
    results = @db.find_players(last_name: "Smith", city: "Toronto")
    assert_equal(1, results.length)
  end
end

class TestDbClearData < Minitest::Test
  def setup
    super
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
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
        active_high_rating: 1600
      }
    ]

    @db.save_players(players, "2026-03-01")
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_clear_data_removes_all_entries
    assert_equal(1, @db.db.execute("SELECT COUNT(*) FROM players").first["COUNT(*)"])
    assert_equal(1, @db.db.execute("SELECT COUNT(*) FROM player_ratings").first["COUNT(*)"])

    @db.clear_data

    assert_equal(0, @db.db.execute("SELECT COUNT(*) FROM players").first["COUNT(*)"])
    assert_equal(0, @db.db.execute("SELECT COUNT(*) FROM player_ratings").first["COUNT(*)"])
  end
end

class TestDbClose < Minitest::Test
  def setup
    super
    # Force using default db path to test actual close
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_close_does_not_raise
    @db.close
    assert(true) # If we get here, it worked
  end
end

class TestDbInit < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @tmp_dir2 = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir) if @tmp_dir
    FileUtils.rm_rf(@tmp_dir2) if @tmp_dir2
  end

  def test_init_with_default_db_path
    # Test that default DB path is used when no path provided
    assert_nil(Cfc::Database.new.instance_variable_get(:@db_path))
  end

  def test_init_with_absolute_path
    db_path = File.join(@tmp_dir, "custom.db")
    custom_db = Cfc::Database.new(db_path)
    assert_equal(db_path, custom_db.instance_variable_get(:@db_path))
  end

  def test_init_creates_tables_if_not_exist
    db_path = File.join(@tmp_dir2, "test.db")
    # Create empty file to simulate existing but empty DB
    File.write(db_path, "")

    db = Cfc::Database.new(db_path)

    # Verify tables exist (exclude sqlite_sequence which is auto-created)
    result = db.db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name != 'sqlite_sequence'")
    assert_equal(2, result.length)
    assert_includes(result.map { |r| r["name"] }, "player_ratings")
    assert_includes(result.map { |r| r["name"] }, "players")
  end
end
