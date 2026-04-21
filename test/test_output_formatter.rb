# frozen_string_literal: true

require "test_helper"
require "cfc/output_formatter"

class TestOutputFormatter < Minitest::Test
  # --- Diff HTML tests ---

  def test_format_html_diff_with_new_players
    changes = {
      new: [{ cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1500, active_rating: 1500, expire_date: nil }],
      removed: [],
      changed: []
    }

    output = Cfc::OutputFormatter.format(changes, "html", type: :diff)
    refute_nil(output)
    assert_match(/<!DOCTYPE html>/, output)
    assert_match(/New Players: 1/, output)
    assert_match(/John Smith/, output)
    assert_match(/100001/, output)
  end

  def test_format_html_diff_with_changed_players
    changes = {
      new: [],
      removed: [],
      changed: [{
        cfc_id: 100001,
        from: { rating: 1000, active_rating: 1000 },
        to: { first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1100, active_rating: 1100, expire_date: "2027-01-01" },
        rating_changed: true,
        active_changed: true
      }]
    }

    output = Cfc::OutputFormatter.format(changes, "html", type: :diff)
    assert_match(/Changed Players: 1/, output)
    assert_match(/John Smith/, output)
  end

  def test_format_html_diff_with_retired_players
    changes = {
      new: [],
      removed: [{ cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1500, active_rating: 1500, expire_date: nil }],
      changed: []
    }

    output = Cfc::OutputFormatter.format(changes, "html", type: :diff)
    assert_match(/Retired Players: 1/, output)
    assert_match(/class="removed"/, output)
  end

  def test_format_html_diff_empty
    changes = { new: [], removed: [], changed: [] }
    output = Cfc::OutputFormatter.format(changes, "html", type: :diff)
    assert_match(/<!DOCTYPE html>/, output)
    assert_match(/Summary/, output)
  end

  # --- Diff CSV tests ---

  def test_format_csv_diff_with_new_players
    changes = {
      new: [{ cfc_id: 100001, first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1500, active_rating: 1500, expire_date: nil }],
      removed: [],
      changed: []
    }

    output = Cfc::OutputFormatter.format(changes, "csv", type: :diff)
    assert_match(/type,cfc_id,first_name/, output)
    assert_match(/new,100001,John,Smith/, output)
  end

  def test_format_csv_diff_with_changed_players
    changes = {
      new: [],
      removed: [],
      changed: [{
        cfc_id: 100001,
        from: { rating: 1000, active_rating: 1000 },
        to: { first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1100, active_rating: 1100, expire_date: nil },
        rating_changed: true,
        active_changed: true
      }]
    }

    output = Cfc::OutputFormatter.format(changes, "csv", type: :diff)
    assert_match(/changed,100001,John,Smith/, output)
    assert_match(/from_rating,to_rating/, output)
  end

  def test_format_csv_diff_empty
    changes = { new: [], removed: [], changed: [] }
    output = Cfc::OutputFormatter.format(changes, "csv", type: :diff)
    assert_match(/Summary/, output)
    assert_match(/new,0/, output)
  end

  # --- History HTML tests ---

  def test_format_html_history
    data = {
      player: { "cfc_id" => 100001, "first_name" => "John", "last_name" => "Smith" },
      history: [
        { "rating_date" => "2024-01-01", "rating" => 1000, "active_rating" => 1000 },
        { "rating_date" => "2024-02-01", "rating" => 1100, "active_rating" => 1100 }
      ]
    }

    output = Cfc::OutputFormatter.format(data, "html", type: :history)
    assert_match(/<!DOCTYPE html>/, output)
    assert_match(/John Smith/, output)
    assert_match(/100001/, output)
    assert_match(/2024-01-01/, output)
    assert_match(/2024-02-01/, output)
  end

  # --- History CSV tests ---

  def test_format_csv_history
    data = {
      player: { "cfc_id" => 100001, "first_name" => "John", "last_name" => "Smith" },
      history: [
        { "rating_date" => "2024-01-01", "rating" => 1000, "active_rating" => 1000 }
      ]
    }

    output = Cfc::OutputFormatter.format(data, "csv", type: :history)
    assert_match(/# Rating History for John Smith/, output)
    assert_match(/date,rating,active_rating/, output)
    assert_match(/2024-01-01,1000,1000/, output)
  end

  # --- Show HTML tests ---

  def test_format_html_show
    player = {
      "cfc_id" => 100001,
      "first_name" => "John",
      "last_name" => "Smith",
      "province" => "ON",
      "city" => "Toronto",
      "rating" => 1500,
      "active_rating" => 1500,
      "rating_date" => "2024-01-01",
      "expire_date" => "2027-01-01"
    }

    output = Cfc::OutputFormatter.format(player, "html", type: :show)
    assert_match(/<!DOCTYPE html>/, output)
    assert_match(/John Smith/, output)
    assert_match(/100001/, output)
    assert_match(/ON/, output)
    assert_match(/Toronto/, output)
  end

  # --- Show CSV tests ---

  def test_format_csv_show
    player = {
      "cfc_id" => 100001,
      "first_name" => "John",
      "last_name" => "Smith",
      "province" => "ON",
      "city" => "Toronto",
      "rating" => 1500,
      "active_rating" => 1500,
      "rating_date" => "2024-01-01",
      "expire_date" => "2027-01-01"
    }

    output = Cfc::OutputFormatter.format(player, "csv", type: :show)
    assert_match(/# Player Information/, output)
    assert_match(/name,John Smith/, output)
    assert_match(/cfc_id,100001/, output)
    assert_match(/rating,1500/, output)
  end

  # --- Find HTML tests ---

  def test_format_html_find
    players = [
      { "cfc_id" => 100001, "first_name" => "John", "last_name" => "Smith", "province" => "ON", "city" => "Toronto", "rating" => 1500, "active_rating" => 1500 },
      { "cfc_id" => 100002, "first_name" => "Jane", "last_name" => "Doe", "province" => "BC", "city" => "Vancouver", "rating" => 1600, "active_rating" => 1600 }
    ]

    output = Cfc::OutputFormatter.format(players, "html", type: :find)
    assert_match(/<!DOCTYPE html>/, output)
    assert_match(/2 players found/, output)
    assert_match(/John Smith/, output)
    assert_match(/Jane Doe/, output)
  end

  def test_format_html_find_single_player
    players = [
      { "cfc_id" => 100001, "first_name" => "John", "last_name" => "Smith", "province" => "ON", "city" => "Toronto", "rating" => 1500, "active_rating" => 1500 }
    ]

    output = Cfc::OutputFormatter.format(players, "html", type: :find)
    assert_match(/1 player found/, output)
  end

  # --- Find CSV tests ---

  def test_format_csv_find
    players = [
      { "cfc_id" => 100001, "first_name" => "John", "last_name" => "Smith", "province" => "ON", "city" => "Toronto", "rating" => 1500, "active_rating" => 1500 }
    ]

    output = Cfc::OutputFormatter.format(players, "csv", type: :find)
    assert_match(/# Search Results/, output)
    assert_match(/cfc_id,first_name,last_name/, output)
    assert_match(/100001,John,Smith,ON,Toronto,1500,1500/, output)
  end

  # --- Helper tests ---

  def test_display_expire_info_with_nil
    assert_equal("Unknown", Cfc::OutputFormatter.display_expire_info(nil))
  end

  def test_display_expire_info_with_empty
    assert_equal("Unknown", Cfc::OutputFormatter.display_expire_info(""))
  end

  def test_display_expire_info_with_life_membership
    assert_equal("LIFE", Cfc::OutputFormatter.display_expire_info("2080-01-01"))
  end

  def test_display_expire_info_with_regular_date
    assert_equal("2027-01-01", Cfc::OutputFormatter.display_expire_info("2027-01-01"))
  end

  def test_format_rating_change_no_change
    result = Cfc::OutputFormatter.format_rating_change(1000, 1000, false)
    assert_equal("1000", result)
  end

  def test_format_rating_change_increase
    result = Cfc::OutputFormatter.format_rating_change(1000, 1100, true)
    assert_match(/1000/, result)
    assert_match(/1100/, result)
    assert_match(/\+100/, result)
  end

  def test_format_rating_change_decrease
    result = Cfc::OutputFormatter.format_rating_change(1100, 1000, true)
    assert_match(/-100/, result)
  end

  def test_format_rating_change_with_nil_values
    result = Cfc::OutputFormatter.format_rating_change(nil, 1000, true)
    assert_match(/0/, result)
    assert_match(/1000/, result)
  end

  # --- Text format returns nil ---

  def test_format_text_returns_nil
    assert_nil(Cfc::OutputFormatter.format({}, "text", type: :diff))
  end

  def test_format_unknown_format_returns_nil
    assert_nil(Cfc::OutputFormatter.format({}, "json", type: :diff))
  end

  # --- Expired membership date tests ---

  def test_expire_html_for_expired_date
    result = Cfc::OutputFormatter.expire_html_for("2021-01-01", "2021-01-01")
    assert_match(/class="expired"/, result)
    assert_match(/2021-01-01/, result)
  end

  def test_expire_html_for_future_date
    result = Cfc::OutputFormatter.expire_html_for("2028-01-01", "2028-01-01")
    refute_match(/class="expired"/, result)
    assert_match(/2028-01-01/, result)
  end

  def test_expire_html_for_life_membership
    result = Cfc::OutputFormatter.expire_html_for("2080-01-01", "LIFE")
    refute_match(/class="expired"/, result)
    assert_equal("LIFE", result)
  end

  def test_expire_html_for_nil
    result = Cfc::OutputFormatter.expire_html_for(nil, "Unknown")
    assert_equal("Unknown", result)
  end

  def test_expire_html_for_empty
    result = Cfc::OutputFormatter.expire_html_for("", "Unknown")
    assert_equal("Unknown", result)
  end

  def test_expire_html_for_invalid_date
    result = Cfc::OutputFormatter.expire_html_for("not-a-date", "not-a-date")
    refute_match(/class="expired"/, result)
    assert_match(/not-a-date/, result)
  end

  def test_format_html_diff_with_expired_membership
    changes = {
      new: [],
      removed: [],
      changed: [{
        cfc_id: 100001,
        from: { rating: 1000, active_rating: 1000 },
        to: { first_name: "John", last_name: "Smith", province: "ON", city: "Toronto", rating: 1100, active_rating: 1100, expire_date: "2021-01-01" },
        rating_changed: true,
        active_changed: false
      }]
    }

    output = Cfc::OutputFormatter.format(changes, "html", type: :diff)
    assert_match(/class="expired"/, output)
    assert_match(/2021-01-01/, output)
  end

  def test_format_html_show_with_expired_membership
    player = {
      "cfc_id" => 100001,
      "first_name" => "John",
      "last_name" => "Smith",
      "province" => "ON",
      "city" => "Toronto",
      "rating" => 1500,
      "active_rating" => 1500,
      "rating_date" => "2024-01-01",
      "expire_date" => "2021-01-01"
    }

    output = Cfc::OutputFormatter.format(player, "html", type: :show)
    assert_match(/class="expired"/, output)
    assert_match(/2021-01-01/, output)
  end

  def test_format_html_show_with_valid_membership
    player = {
      "cfc_id" => 100001,
      "first_name" => "John",
      "last_name" => "Smith",
      "province" => "ON",
      "city" => "Toronto",
      "rating" => 1500,
      "active_rating" => 1500,
      "rating_date" => "2024-01-01",
      "expire_date" => "2028-01-01"
    }

    output = Cfc::OutputFormatter.format(player, "html", type: :show)
    refute_match(/class="expired"/, output)
    assert_match(/2028-01-01/, output)
  end
end
