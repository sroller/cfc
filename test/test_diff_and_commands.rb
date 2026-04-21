# frozen_string_literal: true

require "test_helper"
require "cfc/diff"
require "cfc/db"
require "cfc/commands/history"
require "cfc/commands/show"
require "cfc/commands/find"
require "cfc/commands/cleanup"
require "cfc/mailer"
require "stringio"
require "tmpdir"

class TestDiff < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    populate_ratings_data
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def populate_ratings_data
    @db.db.execute(<<-SQL)
      INSERT INTO players (cfc_id, last_name, first_name, province, city) VALUES
      (100001, 'Smith', 'John', 'ON', 'Toronto'),
      (100002, 'Doe', 'Jane', 'BC', 'Vancouver'),
      (100003, 'Johnson', 'Bob', 'AB', 'Calgary')
    SQL

    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100001, 1000, 1000, '2024-01-01', '2024-01-01'),
      (100002, 1500, 1500, '2024-01-01', '2024-01-01'),
      (100003, 1200, 1200, '2024-01-01', '2024-01-01'),
      (100001, 1100, 1100, '2024-02-01', '2024-02-01'),
      (100002, 1600, 1600, '2024-02-01', '2024-02-01'),
      (100003, NULL, NULL, '2024-02-01', '2024-02-01')
    SQL
  end

  # --- parse_ids tests ---
  def test_parse_ids_empty_string
    assert_equal([], Cfc::Diff.parse_ids(""))
  end

  def test_parse_ids_single_id
    assert_equal([100001], Cfc::Diff.parse_ids("100001"))
  end

  def test_parse_ids_multiple_ids
    assert_equal([100001, 100002, 100003], Cfc::Diff.parse_ids("100001,100002,100003"))
  end

  def test_parse_ids_with_spaces
    assert_equal([100001, 100002], Cfc::Diff.parse_ids("100001, 100002 "))
  end

  def test_parse_ids_with_leading_zeros
    assert_equal([100001, 100002], Cfc::Diff.parse_ids("00100001,000100002"))
  end

  def test_parse_ids_with_negative_numbers
    assert_equal([-1, -2, 100001], Cfc::Diff.parse_ids("-1,-2,100001"))
  end

  # --- parse_ids_file tests ---
  def test_parse_ids_file_nonexistent
    result = Cfc::Diff.parse_ids_file("/nonexistent/path.txt")
    assert_nil(result)
  end

  def test_parse_ids_file_with_content
    tmpfile = File.join(@tmp_dir, "ids.txt")
    File.write(tmpfile, "100001\n100002\n")
    ids = Cfc::Diff.parse_ids_file(tmpfile)
    assert_equal([100001, 100002], ids)
  end

  def test_parse_ids_file_with_empty_lines
    tmpfile = File.join(@tmp_dir, "ids.txt")
    File.write(tmpfile, "100001\n\n100002\n\n")
    ids = Cfc::Diff.parse_ids_file(tmpfile)
    assert_equal([100001, 100002], ids)
  end

  def test_parse_ids_file_with_non_numeric_lines
    tmpfile = File.join(@tmp_dir, "ids.txt")
    File.write(tmpfile, "100001\nabc\n100002\n")
    ids = Cfc::Diff.parse_ids_file(tmpfile)
    assert_equal([100001, 100002], ids)
  end

  def test_parse_ids_file_expands_tilde
    # Create a file in home directory simulation
    home = Dir.home
    test_dir = File.join(home, ".cfc_test_tmp")
    Dir.mkdir(test_dir) unless Dir.exist?(test_dir)
    test_file = File.join(test_dir, "ids.txt")
    File.write(test_file, "100001\n100002\n")

    # Use tilde path
    tilde_path = File.join("~", ".cfc_test_tmp", "ids.txt")
    ids = Cfc::Diff.parse_ids_file(tilde_path)
    assert_equal([100001, 100002], ids)
  ensure
    FileUtils.rm_rf(test_dir) if Dir.exist?(test_dir)
  end

  # --- get_players_by_date tests ---
  def test_get_players_by_date_returns_data
    players = Cfc::Diff.get_players_by_date(@db, "2024-01-01")
    assert_equal(3, players.length)
    assert_equal("John", players[0][:first_name])
    assert_equal("Smith", players[0][:last_name])
  end

  def test_get_players_by_date_empty
    players = Cfc::Diff.get_players_by_date(@db, "2023-01-01")
    assert_empty(players)
  end

  # --- get_default_dates tests ---
  def test_get_default_dates_returns_two_latest
    from, to = Cfc::Diff.get_default_dates(@db)
    assert_equal("2024-01-01", from)
    assert_equal("2024-02-01", to)
  end

  def test_get_default_dates_sorts_correctly
    from, to = Cfc::Diff.get_default_dates(@db)
    assert_equal("2024-01-01", from)
    assert_equal("2024-02-01", to)
  end

  def test_get_default_dates_raises_exit_not_enough_data
    tmp_db = File.join(@tmp_dir, "test2.db")
    db = Cfc::Database.new(tmp_db)

    # Only create one rating date worth of data
    db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (1, 1000, 1000, '2024-01-01', '2024-01-01')
    SQL

    assert_raises(SystemExit) do
      Cfc::Diff.get_default_dates(db)
    end
  end

  # --- compare_players tests ---
  def test_compare_players_all_three_categories
    from_players = Cfc::Diff.get_players_by_date(@db, "2024-01-01")
    to_players = Cfc::Diff.get_players_by_date(@db, "2024-02-01")

    changes = Cfc::Diff.compare_players(from_players, to_players)

    assert_equal(0, changes[:new].length)    # No new players in this case
    assert_equal(0, changes[:removed].length)  # Johnson is still in both dates
    assert_equal(3, changes[:changed].length)  # Smith, Doe, and Johnson (nil ratings) changed
  end

  def test_compare_players_no_changes
    from_players = Cfc::Diff.get_players_by_date(@db, "2024-01-01")
    to_players = []

    changes = Cfc::Diff.compare_players(from_players, to_players)
    assert_equal(from_players.length, changes[:removed].length)
    assert_empty(changes[:new])
    assert_empty(changes[:changed])
  end

  def test_compare_players_both_empty
    from_players = []
    to_players = []
    changes = Cfc::Diff.compare_players(from_players, to_players)
    assert_empty(changes[:new])
    assert_empty(changes[:removed])
    assert_empty(changes[:changed])
  end

  def test_compare_players_rating_only_changed
    from_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1000, active_rating: 1000 }
    ]
    to_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1100, active_rating: 1000 }
    ]

    changes = Cfc::Diff.compare_players(from_players, to_players)

    assert_empty(changes[:new])
    assert_empty(changes[:removed])
    assert_equal(1, changes[:changed].length)
    assert_equal(true, changes[:changed][0][:rating_changed])
    assert_equal(false, changes[:changed][0][:active_changed])
  end

  def test_compare_players_active_only_changed
    from_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1000, active_rating: 1000 }
    ]
    to_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1000, active_rating: 1100 }
    ]

    changes = Cfc::Diff.compare_players(from_players, to_players)

    assert_empty(changes[:new])
    assert_empty(changes[:removed])
    assert_equal(1, changes[:changed].length)
    assert_equal(false, changes[:changed][0][:rating_changed])
    assert_equal(true, changes[:changed][0][:active_changed])
  end

  def test_compare_players_both_ratings_changed
    from_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1000, active_rating: 1000 }
    ]
    to_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1100, active_rating: 1100 }
    ]

    changes = Cfc::Diff.compare_players(from_players, to_players)

    assert_empty(changes[:new])
    assert_empty(changes[:removed])
    assert_equal(1, changes[:changed].length)
    assert_equal(true, changes[:changed][0][:rating_changed])
    assert_equal(true, changes[:changed][0][:active_changed])
  end

  def test_compare_players_nil_ratings_from
    from_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: nil, active_rating: nil }
    ]
    to_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1000, active_rating: 1000 }
    ]

    changes = Cfc::Diff.compare_players(from_players, to_players)

    assert_empty(changes[:new])
    assert_empty(changes[:removed])
    assert_equal(1, changes[:changed].length)
  end

  def test_compare_players_nil_ratings_to
    from_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1000, active_rating: 1000 }
    ]
    to_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: nil, active_rating: nil }
    ]

    changes = Cfc::Diff.compare_players(from_players, to_players)

    assert_empty(changes[:new])
    assert_empty(changes[:removed])
    assert_equal(1, changes[:changed].length)
  end

  def test_compare_players_same_ratings_no_change
    from_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1000, active_rating: 1000 }
    ]
    to_players = [
      { cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1000, active_rating: 1000 }
    ]

    changes = Cfc::Diff.compare_players(from_players, to_players)

    assert_empty(changes[:new])
    assert_empty(changes[:removed])
    assert_empty(changes[:changed])
  end

  def test_compare_players_single_player_new
    from_players = []
    to_players = [
      { cfc_id: 100001, first_name: "New", last_name: "Player", province: "ON", city: "Toronto", rating: 1500, active_rating: 1500 }
    ]

    changes = Cfc::Diff.compare_players(from_players, to_players)

    assert_equal(1, changes[:new].length)
    assert_empty(changes[:removed])
    assert_empty(changes[:changed])
  end

  def test_compare_players_single_player_removed
    from_players = [
      { cfc_id: 100001, first_name: "Removed", last_name: "Player", province: "ON", city: "Toronto", rating: 1500, active_rating: 1500 }
    ]
    to_players = []

    changes = Cfc::Diff.compare_players(from_players, to_players)

    assert_empty(changes[:new])
    assert_equal(1, changes[:removed].length)
    assert_empty(changes[:changed])
  end

  def test_compare_players_many_new_many_removed_many_changed
    from_players = [
      { cfc_id: 1, first_name: "A", last_name: "Alpha", province: "AB", city: "Calgary", rating: 1000, active_rating: 1000 },
      { cfc_id: 2, first_name: "B", last_name: "Beta", province: "BC", city: "Vancouver", rating: 1100, active_rating: 1100 },
      { cfc_id: 3, first_name: "C", last_name: "Charlie", province: "ON", city: "Toronto", rating: 1200, active_rating: 1200 }
    ]
    to_players = [
      { cfc_id: 2, first_name: "B", last_name: "Beta", province: "BC", city: "Vancouver", rating: 1200, active_rating: 1200 },
      { cfc_id: 3, first_name: "C", last_name: "Charlie", province: "ON", city: "Toronto", rating: 1200, active_rating: 1250 },
      { cfc_id: 4, first_name: "D", last_name: "Delta", province: "MB", city: "Winnipeg", rating: 1300, active_rating: 1300 },
      { cfc_id: 5, first_name: "E", last_name: "Echo", province: "QC", city: "Montreal", rating: 1400, active_rating: 1400 }
    ]

    changes = Cfc::Diff.compare_players(from_players, to_players)

    assert_equal(2, changes[:new].length)      # Delta, Echo
    assert_equal(1, changes[:removed].length)  # Alpha
    assert_equal(2, changes[:changed].length)  # Beta (rating), Charlie (active)
  end

  # --- print_changes tests ---
  def test_print_changes_with_new_players
    changes = {
      new: [
        {
          cfc_id: 100001,
          first_name: "New",
          last_name: "Player",
          province: "ON",
          city: "Toronto",
          rating: 1500,
          active_rating: 1500
        }
      ],
      removed: [],
      changed: []
    }

    output = capture_io do
      Cfc::Diff.print_changes(changes)
    end

    refute_nil(output)
    assert_match(/New Players: 1/, output)
    assert_match(/New Player/, output)
  end

  def test_print_changes_with_retired_players
    changes = {
      new: [],
      removed: [
        {
          cfc_id: 100002,
          first_name: "Retired",
          last_name: "Player",
          province: "BC",
          city: "Vancouver",
          rating: 1400,
          active_rating: 1400
        }
      ],
      changed: []
    }

    output = capture_io do
      Cfc::Diff.print_changes(changes)
    end

    refute_nil(output)
    assert_match(/Retired Players: 1/, output)
    assert_match(/Retired Player/, output)
  end

  def test_print_changes_with_changed_players
    changes = {
      new: [],
      removed: [],
      changed: [
        {
          cfc_id: 100003,
          first_name: "Changed",
          last_name: "Player",
          province: "AB",
          city: "Calgary",
          from: { first_name: "Changed", last_name: "Player", rating: 1000, active_rating: 1500 },
          to: { first_name: "Changed", last_name: "Player", rating: 1100, active_rating: 1500 },
          rating_changed: true,
          active_changed: false
        }
      ]
    }

    output = capture_io do
      Cfc::Diff.print_changes(changes)
    end

    refute_nil(output)
    assert_match(/Changed Players: 1/, output)
    assert_match(/Changed Player/, output)
  end

  def test_print_changes_all_categories_together
    changes = {
      new: [
        {
          cfc_id: 100001,
          first_name: "New",
          last_name: "Player",
          province: "ON",
          city: "Toronto",
          rating: 1500,
          active_rating: 1500
        }
      ],
      removed: [
        {
          cfc_id: 100002,
          first_name: "Retired",
          last_name: "Player",
          province: "BC",
          city: "Vancouver",
          rating: 1400,
          active_rating: 1400
        }
      ],
      changed: [
        {
          cfc_id: 100003,
          first_name: "Changed",
          last_name: "Player",
          province: "AB",
          city: "Calgary",
          from: { rating: 1000, active_rating: 1000 },
          to: { rating: 1100, active_rating: 1100 },
          rating_changed: true,
          active_changed: true
        }
      ]
    }

    output = capture_io do
      Cfc::Diff.print_changes(changes)
    end

    assert_match(/New Players: 1/, output)
    assert_match(/Retired Players: 1/, output)
    assert_match(/Changed Players: 1/, output)
    assert_match(/Summary:/, output)
    assert_match(/New: 1/, output)
    assert_match(/Retired: 1/, output)
    assert_match(/Changed: 1/, output)
  end

  def test_print_changes_with_nil_province_city
    changes = {
      new: [
        {
          cfc_id: 100001,
          first_name: "No Location",
          last_name: "Player",
          province: nil,
          city: nil,
          rating: 1500,
          active_rating: 1500
        }
      ],
      removed: [],
      changed: []
    }

    output = capture_io do
      Cfc::Diff.print_changes(changes)
    end

    assert_match(/New Players: 1/, output)
    assert_match(/No Location Player/, output)
    # Should not have location in parentheses
    refute_match(/\(.*\)/, output)
  end

  def test_print_changes_with_nil_ratings
    changes = {
      new: [
        {
          cfc_id: 100001,
          first_name: "No Rating",
          last_name: "Player",
          province: "ON",
          city: "Toronto",
          rating: nil,
          active_rating: nil
        }
      ],
      removed: [],
      changed: []
    }

    output = capture_io do
      Cfc::Diff.print_changes(changes)
    end

    assert_match(/New Players: 1/, output)
    assert_match(/Rating: /, output)
  end

  def test_print_changes_no_changes_empty
    changes = {
      new: [],
      removed: [],
      changed: []
    }

    output = capture_io do
      Cfc::Diff.print_changes(changes)
    end

    assert_match(/=== Rating Changes ===/, output)
    assert_match(/Summary:/, output)
    assert_match(/New: 0/, output)
    refute_match(/Retired/, output)
    assert_match(/Changed: 0/, output)
  end

  # --- run tests ---
  def test_run_with_from_and_to_dates
    output = capture_io do
      Cfc::Diff.run(from: "2024-01-01", to: "2024-02-01", show_spinner: false, db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Rating Changes/, output)
  end

  def test_run_with_ids_filter
    output = capture_io do
      Cfc::Diff.run(from: "2024-01-01", to: "2024-02-01", ids: "100001,100002", show_spinner: false, db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Smith/, output)
    assert_match(/Doe/, output)
    # Johnson should not appear with IDs filter
    refute_match(/Johnson/, output)
  end

  def test_run_with_ids_file_filter
    tmpfile = File.join(@tmp_dir, "ids.txt")
    File.write(tmpfile, "100001\n100003\n")

    output = capture_io do
      Cfc::Diff.run(from: "2024-01-01", to: "2024-02-01", ids_file: tmpfile, show_spinner: false, db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Smith/, output)
    # Should include Johnson's retirement but not Doe
    assert_match(/Johnson/, output)
  end

  # --- display_expire_info tests ---
  def test_display_expire_info_with_regular_date
    assert_equal("Membership: 2025-12-31", Cfc::Diff.display_expire_info("2025-12-31"))
  end

  def test_display_expire_info_with_life_membership
    assert_equal("Membership: LIFE", Cfc::Diff.display_expire_info("2080-12-31"))
  end

  def test_display_expire_info_with_nil
    assert_equal("Membership: Unknown", Cfc::Diff.display_expire_info(nil))
  end

  def test_display_expire_info_with_empty_string
    assert_equal("Membership: Unknown", Cfc::Diff.display_expire_info(""))
  end

  def test_display_expire_info_with_50_years_plus
    assert_equal("Membership: LIFE", Cfc::Diff.display_expire_info("2080-01-01"))
  end

  def test_display_expire_info_with_50_years_minus
    # About 50 years from now (2026 + 50 = 2076)
    refute_equal("Membership: LIFE", Cfc::Diff.display_expire_info("2075-12-31"))
  end

  # --- cron tests ---
  def test_diff_has_changes_with_new_players
    output = "=== Rating Changes ===\n\nNew Players: 1\n"
    assert(Cfc::Diff.diff_has_changes?(output))
  end

  def test_diff_has_changes_with_retired_players
    output = "=== Rating Changes ===\n\nRetired Players: 1\n"
    assert(Cfc::Diff.diff_has_changes?(output))
  end

  def test_diff_has_changes_with_changed_players
    output = "=== Rating Changes ===\n\nChanged Players: 1\n"
    assert(Cfc::Diff.diff_has_changes?(output))
  end

  def test_diff_has_changes_with_no_changes
    output = "=== Rating Changes ===\n\nSummary:\n  New: 0\n  Changed: 0\n"
    refute(Cfc::Diff.diff_has_changes?(output))
  end

  def test_diff_has_changes_with_empty_output
    refute(Cfc::Diff.diff_has_changes?(""))
  end

  def test_run_cron_detects_change
    # With existing data that has changes, cron should detect and return
    output = capture_io do
      Cfc::Diff.run_cron(ids_file: nil, db_path: @db_path, check_interval: 0.1)
    end

    refute_nil(output)
    assert_match(/Update detected/, output)
  end

  def test_run_cron_with_mail_sends_email
    emails_sent = []

    # Mock Mailer to track email sends
    original_send = Cfc::Mailer.method(:send_mail)
    Cfc::Mailer.define_singleton_method(:send_mail) do |recipients, subject, body, from: nil|
      emails_sent << { recipients: recipients, subject: subject, body: body }
    end

    output = capture_io do
      Cfc::Diff.run_cron(ids_file: nil, db_path: @db_path, check_interval: 0.1, mail: "test@example.com")
    end

    assert_equal(1, emails_sent.length)
    assert_match(/Rating Changes Detected/, emails_sent[0][:subject])
    assert_includes(emails_sent[0][:recipients], "test@example.com")
    assert_match(/<!DOCTYPE html>/, emails_sent[0][:body])
  ensure
    Cfc::Mailer.define_singleton_method(:send_mail, original_send)
  end

  # --- normalize_date tests ---
  def test_normalize_date_yyyymmdd_format
    assert_equal("2026-01-01", Cfc::Diff.normalize_date("20260101"))
  end

  def test_normalize_date_already_formatted
    assert_equal("2026-01-01", Cfc::Diff.normalize_date("2026-01-01"))
  end

  def test_normalize_date_invalid_format
    assert_equal("invalid", Cfc::Diff.normalize_date("invalid"))
  end

  def test_normalize_date_short_string
    assert_equal("2026", Cfc::Diff.normalize_date("2026"))
  end

end

class TestCommandsHistory < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    populate_history_data
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def populate_history_data
    @db.db.execute(<<-SQL)
      INSERT INTO players (cfc_id, last_name, first_name, province, city) VALUES
      (100001, 'Smith', 'John', 'ON', 'Toronto'),
      (100002, 'Doe', 'Jane', 'BC', 'Vancouver')
    SQL

    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100001, 1000, 1000, '2024-01-01', '2024-01-01'),
      (100001, 1100, 1100, '2024-02-01', '2024-02-01'),
      (100001, 1200, 1200, '2024-03-01', '2024-03-01'),
      (100002, 1500, 1500, '2024-01-01', '2024-01-01'),
      (100002, 1600, 1600, '2024-03-01', '2024-03-01')
    SQL
  end

  def test_run_with_valid_cfc_id
    output = capture_io do
      Cfc::Commands::History.run("100001", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Rating History for John Smith/, output)
    assert_match(/CFC ID:.*100001/, output)
  end

  def test_run_with_invalid_cfc_id
    output = capture_io do
      Cfc::Commands::History.run("999999", db_path: @db_path)
    end

    assert_match(/Player not found: 999999/, output)
  end

  def test_run_with_date_range_from_only
    output = capture_io do
      Cfc::Commands::History.run("100001", from: "2024-02-01", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Rating History for John Smith/, output)
    refute_match(/2024-01-01: Rating: 1000/, output)
  end

  def test_run_with_date_range_to_only
    output = capture_io do
      Cfc::Commands::History.run("100001", to: "2024-02-28", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Rating History for John Smith/, output)
    refute_match(/2024-03-01: Rating: 1200/, output)
  end

  def test_run_with_date_range_both_dates
    output = capture_io do
      Cfc::Commands::History.run("100001", from: "2024-01-15", to: "2024-02-28", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Rating History for John Smith/, output)
    assert_match(/2024-02-01: Rating: 1100, Active: 1100/, output)
  end

  def test_run_with_invalid_cfc_id_string
    output = capture_io do
      Cfc::Commands::History.run("abc", db_path: @db_path)
    end

    assert_match(/Invalid CFC ID/, output)
  end

  def test_display_player_history_nil_player
    output = capture_io do
      Cfc::Commands::History.display_player_history(@db, 999999, nil, nil)
    end

    assert_match(/Player not found: 999999/, output)
  end

  def test_display_history_nil_history
    player_data = { "first_name" => "Test", "last_name" => "User", "cfc_id" => 100001 }

    output = capture_io do
      Cfc::Commands::History.display_history(player_data, [])
    end

    # Output shows "Total records: 0" when history is empty
    assert_match(/Total records: 0/, output)
  end

  def test_format_date_with_valid_date
    assert_equal("2024-01-01", Cfc::Commands::History.format_date("20240101"))
  end

  def test_format_date_with_already_formatted_date
    assert_equal("2024-01-01", Cfc::Commands::History.format_date("2024-01-01"))
  end

  def test_parse_ids_file_nonexistent
    result = Cfc::Commands::History.parse_ids_file("/nonexistent/path.txt")
    assert_empty(result)
  end

  def test_parse_ids_file_with_content
    tmpfile = File.join(@tmp_dir, "ids.txt")
    File.write(tmpfile, "100001\n100002\n")
    ids = Cfc::Commands::History.parse_ids_file(tmpfile)
    assert_equal([100001, 100002], ids)
  end

  def test_parse_ids_file_with_empty_lines
    tmpfile = File.join(@tmp_dir, "ids.txt")
    File.write(tmpfile, "100001\n\n100002\n")
    ids = Cfc::Commands::History.parse_ids_file(tmpfile)
    assert_equal([100001, 100002], ids)
  end

  def test_display_player_history_with_nil_rating
    output = capture_io do
      Cfc::Commands::History.display_player_history(@db, 100002, nil, nil)
    end

    refute_nil(output)
    assert_match(/Jane Doe/, output)
    assert_equal(1600, @db.get_current_ratings([100002]).first["rating"])
  end
end

class TestCommandsShow < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    populate_show_data
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def populate_show_data
    @db.db.execute(<<-SQL)
      INSERT INTO players (cfc_id, last_name, first_name, province, city) VALUES
      (100001, 'Smith', 'John', 'ON', 'Toronto'),
      (100002, 'Doe', 'Jane', 'BC', 'Vancouver')
    SQL

    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100001, 1000, 1000, '2024-03-01', '2024-03-01'),
      (100002, 1500, 1500, '2024-03-01', '2024-03-01')
    SQL
  end

  def test_run_with_valid_cfc_id
    output = capture_io do
      Cfc::Commands::Show.run("100001", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Player Information/, output)
    assert_match(/Name:.*John Smith/, output)
    assert_match(/CFC ID:.*100001/, output)
  end

  def test_run_with_invalid_cfc_id
    output = capture_io do
      Cfc::Commands::Show.run("999999", db_path: @db_path)
    end

    assert_match(/Player not found: 999999/, output)
  end

  def test_run_multiple_ids
    output = capture_io do
      Cfc::Commands::Show.run(["100001", "100002"], db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Name:.*John Smith/, output)
    # There should be blank line between players
    assert_match(/Name:.*Jane Doe/, output)
  end

  def test_display_player_info_nil_player
    output = capture_io do
      Cfc::Commands::Show.display_player_info(@db, 999999)
    end

    assert_match(/Player not found: 999999/, output)
  end

  def test_display_player_with_nil_province_city
    player_data = {
      "cfc_id" => 100001,
      "last_name" => "Test",
      "first_name" => "User",
      "province" => nil,
      "city" => nil,
      "rating" => 1500,
      "active_rating" => 1500,
      "rating_date" => "2024-03-01"
    }

    capture_io do
      Cfc::Commands::Show.display_player(player_data)
    end

    output = $stdout.to_s
    refute_match(/Province:/, output)
    refute_match(/City:/, output)
  end

  def test_parse_ids_file_nonexistent
    result = Cfc::Commands::Show.parse_ids_file("/nonexistent/path.txt")
    assert_empty(result)
  end

  def test_parse_ids_file_with_content
    tmpfile = File.join(@tmp_dir, "ids.txt")
    File.write(tmpfile, "100001\n100002\n")
    ids = Cfc::Commands::Show.parse_ids_file(tmpfile)
    assert_equal([100001, 100002], ids)
  end

  def test_parse_ids_file_with_empty_lines
    tmpfile = File.join(@tmp_dir, "ids.txt")
    File.write(tmpfile, "100001\n\n100002\n")
    ids = Cfc::Commands::Show.parse_ids_file(tmpfile)
    assert_equal([100001, 100002], ids)
  end

  def test_display_player_with_no_rating_history
    player_data = {
      "cfc_id" => 100003,
      "last_name" => "No",
      "first_name" => "Rating",
      "province" => "ON",
      "city" => "Toronto",
      "rating" => nil,
      "active_rating" => nil,
      "rating_date" => nil
    }

    output = capture_io do
      Cfc::Commands::Show.display_player(player_data)
    end

    refute_nil(output)
    assert_match(/Rating:       0/, output)
    assert_match(/Active:       0/, output)
  end

  def test_display_expire_date_with_regular_date
    assert_equal("2025-12-31", Cfc::Commands::Show.display_expire_date("2025-12-31"))
  end

  def test_display_expire_date_with_life_membership
    assert_equal("LIFE", Cfc::Commands::Show.display_expire_date("2080-12-31"))
  end

  def test_display_expire_date_with_nil
    assert_equal("Unknown", Cfc::Commands::Show.display_expire_date(nil))
  end

  def test_display_expire_date_with_empty_string
    assert_equal("Unknown", Cfc::Commands::Show.display_expire_date(""))
  end

  def test_display_expire_date_with_50_years_plus
    assert_equal("LIFE", Cfc::Commands::Show.display_expire_date("2080-01-01"))
  end

  def test_display_expire_date_with_50_years_minus
    # About 50 years from now (2026 + 50 = 2076)
    refute_equal("LIFE", Cfc::Commands::Show.display_expire_date("2075-12-31"))
  end

  def test_is_life_membership_with_future_date
    refute(Cfc::Commands::Show.is_life_membership?("2075-12-31"))
  end

  def test_is_life_membership_with_far_future_date
    assert(Cfc::Commands::Show.is_life_membership?("2080-12-31"))
  end

  def test_display_player_with_life_membership
    player_data = {
      "cfc_id" => 100001,
      "last_name" => "Life",
      "first_name" => "Member",
      "province" => "ON",
      "city" => "Toronto",
      "rating" => 1500,
      "active_rating" => 1500,
      "rating_date" => "2024-03-01",
      "expire_date" => "9999-12-31"
    }

    output = capture_io do
      Cfc::Commands::Show.display_player(player_data)
    end

    refute_nil(output)
    assert_match(/Membership:  LIFE/, output)
  end

  def test_display_player_with_regular_membership
    player_data = {
      "cfc_id" => 100001,
      "last_name" => "Regular",
      "first_name" => "Member",
      "province" => "ON",
      "city" => "Toronto",
      "rating" => 1500,
      "active_rating" => 1500,
      "rating_date" => "2024-03-01",
      "expire_date" => "2025-12-31"
    }

    output = capture_io do
      Cfc::Commands::Show.display_player(player_data)
    end

    refute_nil(output)
    assert_match(/Membership:  2025-12-31/, output)
  end
end

class TestCommandsFind < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    populate_find_data
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def populate_find_data
    @db.db.execute(<<-SQL)
      INSERT INTO players (cfc_id, last_name, first_name, province, city) VALUES
      (100001, 'Smith', 'John', 'ON', 'Toronto'),
      (100002, 'Doe', 'Jane', 'BC', 'Vancouver'),
      (100003, 'Johnson', 'Bob', 'AB', 'Calgary'),
      (100004, 'Williams', 'Alice', 'MB', 'Winnipeg')
    SQL

    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100001, 1000, 1000, '2024-03-01', '2024-03-01'),
      (100002, 1500, 1500, '2024-03-01', '2024-03-01'),
      (100003, 1200, 1200, '2024-03-01', '2024-03-01'),
      (100004, 1600, 1600, '2024-03-01', '2024-03-01')
    SQL
  end

  def test_run_with_last_name_only
    output = capture_io do
      Cfc::Commands::Find.run(last_name: "Smith", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Search Results/, output)
    assert_match(/100001: John Smith/, output)
  end

  def test_run_with_first_name_only
    output = capture_io do
      Cfc::Commands::Find.run(first_name: "John", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Search Results/, output)
    assert_match(/100001: John Smith/, output)
  end

  def test_run_with_province_only
    output = capture_io do
      Cfc::Commands::Find.run(province: "BC", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Search Results/, output)
    assert_match(/100002: Jane Doe/, output)
  end

  def test_run_with_city_only
    output = capture_io do
      Cfc::Commands::Find.run(city: "Toronto", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Search Results/, output)
    assert_match(/100001: John Smith/, output)
  end

  def test_run_with_combined_criteria
    output = capture_io do
      Cfc::Commands::Find.run(last_name: "Smith", province: "ON", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Search Results/, output)
    assert_match(/1 player found/, output)
  end

  def test_run_with_no_criteria
    output = capture_io do
      Cfc::Commands::Find.run(last_name: nil, first_name: nil, province: nil, city: nil, db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Search Results.*4 players found/, output)
  end

  def test_run_with_no_matches
    output = capture_io do
      Cfc::Commands::Find.run(last_name: "NonExistent", db_path: @db_path)
    end

    assert_match(/No players found matching the criteria/, output)
  end

  def test_display_results_empty_players
    output = capture_io do
      Cfc::Commands::Find.display_results([])
    end

    refute_nil(output)
    assert_match(/0 player found/, output)
  end

  def test_run_with_last_name_and_city_criteria
    output = capture_io do
      Cfc::Commands::Find.run(last_name: "Doe", city: "Vancouver", db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Jane Doe/, output)
    refute_match(/Johnson/, output)
  end
end

class TestCommandsCleanup < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, "test.db")
    @db = Cfc::Database.new(@db_path)
    populate_cleanup_data
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def populate_cleanup_data
    # Create ratings with duplicates
    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100001, 1000, 1000, '2024-01-01', '2024-01-01'),
      (100001, 1000, 1000, '2024-01-02', '2024-01-02'),
      (100001, 1100, 1100, '2024-01-03', '2024-01-03'),
      (100002, 1500, 1500, '2024-01-01', '2024-01-01'),
      (100002, 1600, 1600, '2024-01-03', '2024-01-03')
    SQL
  end

  def test_run_removes_duplicates
    output = capture_io do
      Cfc::Commands::Cleanup.run(db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Analyzing rating entries for duplicates/, output)
    # Should find 2 duplicates for player 100001
    assert_match(/Found 1 duplicate entries to remove/, output)
  end

  def test_run_no_duplicates
    @db.clear_data

    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100001, 1000, 1000, '2024-01-01', '2024-01-01'),
      (100001, 1100, 1100, '2024-02-01', '2024-02-01'),
      (100002, 1500, 1500, '2024-01-01', '2024-01-01'),
      (100002, 1600, 1600, '2024-02-01', '2024-02-01')
    SQL

    output = capture_io do
      Cfc::Commands::Cleanup.run(db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/No duplicates found/, output)
    assert_match(/Database is clean/, output)
  end

  def test_run_with_different_ratings_not_duplicates
    @db.clear_data

    @db.db.execute(<<-SQL)
      INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES
      (100001, 1000, 1000, '2024-01-01', '2024-01-01'),
      (100001, 1100, 1100, '2024-01-05', '2024-01-05')
    SQL

    output = capture_io do
      Cfc::Commands::Cleanup.run(db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/No duplicates found/, output)
  end

  def test_run_with_batch_deletion
    @db.clear_data

    # Create many duplicates to test batch deletion
    (1..50).each do |i|
      date = i.to_s.rjust(2, '0')
      @db.db.execute(
        "INSERT INTO player_ratings (cfc_id, rating, active_rating, rating_date, download_date) VALUES (?, ?, ?, ?, ?)",
        [100001, 1000, 1000, "2024-01-#{date}", "2024-01-#{date}"]
      )
    end

    output = capture_io do
      Cfc::Commands::Cleanup.run(db_path: @db_path)
    end

    refute_nil(output)
    assert_match(/Found 49 duplicate entries to remove/, output)
  end
end
