# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"
require_relative "../lib/cfc/commands/ids"
require_relative "../lib/cfc/commands/history"
require_relative "../lib/cfc/commands/show"
require_relative "../lib/cfc/diff"

class TestIdsCommand < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @test_db_path = File.join(@tmp_dir, "test_cfc_ratings.db")

    # Create test database with sample data
    @db = Cfc::Database.new(@test_db_path)
    @db.save_players([
                       {
                         cfc_id: 100_001,
                         last_name: "Smith",
                         first_name: "John",
                         province: "ON",
                         city: "Toronto",
                         expire_date: "2027-12-31",
                         rating: 1500,
                         active_rating: 1550,
                         high_rating: 1600,
                         active_high_rating: 1650
                       },
                       {
                         cfc_id: 100_002,
                         last_name: "Johnson",
                         first_name: "Jane",
                         province: "BC",
                         city: "Vancouver",
                         expire_date: "2026-06-30",
                         rating: 1800,
                         active_rating: 1850,
                         high_rating: 1900,
                         active_high_rating: 1950
                       },
                       {
                         cfc_id: 100_003,
                         last_name: "Doe",
                         first_name: "Alice",
                         province: "QC",
                         city: "Montreal",
                         expire_date: "LIFE",
                         rating: 2000,
                         active_rating: 2050,
                         high_rating: 2100,
                         active_high_rating: 2150
                       }
                     ], "2026-04-20", dedupe: false)
    @db.close
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  # Test list subcommand
  def test_list_with_valid_file
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001\n100002\n")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.list(ids_file, db: test_db) }
    test_db.close
    assert_includes output, "100001 John Smith (Toronto, ON)"
    assert_includes output, "100002 Jane Johnson (Vancouver, BC)"
  end

  def test_list_with_nonexistent_file
    output = capture_io { Cfc::Commands::Ids.list("/nonexistent/file.ids") }
    assert_includes output, "Error: File not found"
  end

  def test_list_with_comments
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "# This is a comment\n100001\n# Another comment\n100002\n")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.list(ids_file, db: test_db) }
    test_db.close
    assert_includes output, "100001 John Smith (Toronto, ON)"
    assert_includes output, "100002 Jane Johnson (Vancouver, BC)"
    refute_includes output, "This is a comment"
  end

  def test_list_with_name_annotations
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001 Custom Name One\n100002 Custom Name Two\n")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.list(ids_file, db: test_db) }
    test_db.close
    # Should show actual names from database, not annotations
    assert_includes output, "100001 John Smith (Toronto, ON)"
    assert_includes output, "100002 Jane Johnson (Vancouver, BC)"
  end

  def test_list_with_not_found_id
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "999999\n")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.list(ids_file, db: test_db) }
    test_db.close
    assert_includes output, "999999 [Not found in database]"
  end

  def test_list_with_empty_lines
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "\n100001\n\n100002\n\n")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.list(ids_file, db: test_db) }
    test_db.close
    assert_includes output, "100001 John Smith (Toronto, ON)"
    assert_includes output, "100002 Jane Johnson (Vancouver, BC)"
  end

  # Test add subcommand
  def test_add_new_id
    ids_file = File.join(@tmp_dir, "test.ids")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.add(ids_file, 100_001, db: test_db) }
    test_db.close
    assert File.exist?(ids_file)
    content = File.read(ids_file)
    assert_includes content, "100001 John Smith"
    assert_includes output, "Added 100001 John Smith to"
  end

  def test_add_with_custom_name
    ids_file = File.join(@tmp_dir, "test.ids")

    test_db = Cfc::Database.new(@test_db_path)
    capture_io { Cfc::Commands::Ids.add(ids_file, 100_001, "Custom Name", db: test_db) }
    test_db.close
    content = File.read(ids_file)
    assert_includes content, "100001 Custom Name"
  end

  def test_add_duplicate_id
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001\n")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.add(ids_file, 100_001, db: test_db) }
    test_db.close
    assert_includes output, "Error: ID 100001 already exists"
  end

  def test_add_invalid_id
    ids_file = File.join(@tmp_dir, "test.ids")

    output = capture_io { Cfc::Commands::Ids.add(ids_file, "abc") }
    assert_includes output, "Error: Invalid CFC ID"
  end

  def test_add_creates_directory
    ids_file = File.join(@tmp_dir, "subdir", "test.ids")

    test_db = Cfc::Database.new(@test_db_path)
    capture_io { Cfc::Commands::Ids.add(ids_file, 100_001, db: test_db) }
    test_db.close
    assert File.exist?(ids_file)
  end

  def test_add_not_in_database
    ids_file = File.join(@tmp_dir, "test.ids")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.add(ids_file, 999_999, db: test_db) }
    test_db.close
    assert File.exist?(ids_file)
    content = File.read(ids_file)
    assert_includes content, "999999"
    assert_includes output, "Warning: ID 999999 not found in database"
  end

  # Test remove subcommand
  def test_remove_existing_id
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001\n100002\n100003\n")

    output = capture_io { Cfc::Commands::Ids.remove(ids_file, 100_002) }
    content = File.read(ids_file)
    refute_includes content, "100002"
    assert_includes content, "100001"
    assert_includes content, "100003"
    assert_includes output, "Removed ID 100002 from"
  end

  def test_remove_with_name_annotation
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001 John Smith\n100002 Jane Johnson\n")

    capture_io { Cfc::Commands::Ids.remove(ids_file, 100_001) }
    content = File.read(ids_file)
    refute_includes content, "100001"
    assert_includes content, "100002 Jane Johnson"
  end

  def test_remove_nonexistent_id
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001\n100002\n")

    output = capture_io { Cfc::Commands::Ids.remove(ids_file, 999_999) }
    assert_includes output, "Error: ID 999999 not found"
  end

  def test_remove_nonexistent_file
    output = capture_io { Cfc::Commands::Ids.remove("/nonexistent/file.ids", 100_001) }
    assert_includes output, "Error: File not found"
  end

  def test_remove_invalid_id
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001\n")

    output = capture_io { Cfc::Commands::Ids.remove(ids_file, "abc") }
    assert_includes output, "Error: Invalid CFC ID"
  end

  # Test validate subcommand
  def test_validate_all_valid
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001\n100002\n100003\n")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.validate(ids_file, db: test_db) }
    test_db.close
    assert_includes output, "Total IDs: 3"
    assert_includes output, "Valid: 3"
    assert_includes output, "Invalid: 0"
  end

  def test_validate_with_invalid_ids
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001\n999999\n100002\n")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.validate(ids_file, db: test_db) }
    test_db.close
    assert_includes output, "Total IDs: 3"
    assert_includes output, "Valid: 2"
    assert_includes output, "Invalid: 1"
    assert_includes output, "[NOT FOUND] 999999"
  end

  def test_validate_nonexistent_file
    output = capture_io { Cfc::Commands::Ids.validate("/nonexistent/file.ids") }
    assert_includes output, "Error: File not found"
  end

  def test_validate_with_comments
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "# Comment\n100001\n# Another comment\n100002\n")

    test_db = Cfc::Database.new(@test_db_path)
    output = capture_io { Cfc::Commands::Ids.validate(ids_file, db: test_db) }
    test_db.close
    assert_includes output, "Total IDs: 2"
    assert_includes output, "Valid: 2"
    assert_includes output, "Invalid: 0"
  end

  # Test parse_line helper
  def test_parse_line_with_number_only
    assert_equal 100_001, Cfc::Commands::Ids.parse_line("100001")
  end

  def test_parse_line_with_name
    assert_equal 100_001, Cfc::Commands::Ids.parse_line("100001 John Smith")
  end

  def test_parse_line_with_comment
    assert_equal 100_001, Cfc::Commands::Ids.parse_line("100001 # comment")
  end

  def test_parse_line_with_empty_string
    assert_nil Cfc::Commands::Ids.parse_line("")
  end

  def test_parse_line_with_nil
    assert_nil Cfc::Commands::Ids.parse_line(nil)
  end

  def test_parse_line_with_non_numeric
    assert_nil Cfc::Commands::Ids.parse_line("John Smith")
  end

  def test_parse_line_with_leading_spaces
    assert_equal 100_001, Cfc::Commands::Ids.parse_line("  100001 John Smith")
  end

  # Test integration with other commands
  def test_diff_parse_ids_file_with_names
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001 John Smith\n100002 Jane Johnson\n")

    ids = Cfc::Helpers.parse_ids_file(ids_file)
    assert_equal [100_001, 100_002], ids
  end

  def test_history_parse_ids_file_with_names
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001 John Smith\n# comment\n100002 Jane Johnson\n")

    ids = Cfc::Helpers.parse_ids_file(ids_file)
    assert_equal [100_001, 100_002], ids
  end

  def test_show_parse_ids_file_with_names
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "100001\n100002 Jane Johnson\n")

    ids = Cfc::Helpers.parse_ids_file(ids_file)
    assert_equal [100_001, 100_002], ids
  end

  def test_diff_parse_ids_file_with_comments
    ids_file = File.join(@tmp_dir, "test.ids")
    File.write(ids_file, "# Header comment\n100001\n100002\n# Footer comment\n")

    ids = Cfc::Helpers.parse_ids_file(ids_file)
    assert_equal [100_001, 100_002], ids
  end
end
