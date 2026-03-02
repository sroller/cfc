# frozen_string_literal: true

require "test_helper"
require "cfc/downloader"
require "stringio"

class TestDownloader < Minitest::Test
  def test_parse_csv_line
    line = '191362,2025-12-18,"---","---","ON",Scarborough",0,0,1092,1,,0'
    result = Cfc::Downloader.parse_csv_line(line)

    assert_equal(191_362, result[:cfc_id])
    assert_equal("2025-12-18", result[:expiry])
    assert_nil(result[:last_name])
    assert_nil(result[:first_name])
    assert_equal("ON", result[:province])
    assert_equal("Scarborough", result[:city])
    assert_equal(0, result[:rating])
    assert_equal(1092, result[:active_rating])
  end

  def test_parse_csv_line_with_names
    line = '171117,2019-08-20," Lancman","Kyle","US",New York",1991,1991,1898,1806,75003732,0'
    result = Cfc::Downloader.parse_csv_line(line)

    assert_equal(171_117, result[:cfc_id])
    assert_equal("Lancman", result[:last_name])
    assert_equal("Kyle", result[:first_name])
    assert_equal("US", result[:province])
    assert_equal("New York", result[:city])
    assert_equal(1991, result[:rating])
    assert_equal(1898, result[:active_rating])
    assert_equal("75003732", result[:fide_number])
    assert_equal(0, result[:fide_rating])
  end

  def test_parse_int_with_valid_numbers
    assert_nil(Cfc::Downloader.parse_int(""))
    assert_equal(0, Cfc::Downloader.parse_int("0"))
    assert_equal(1500, Cfc::Downloader.parse_int("1500"))
    assert_equal(1, Cfc::Downloader.parse_int("1"))
  end

  def test_parse_int_with_invalid
    assert_nil(Cfc::Downloader.parse_int("abc"))
    assert_nil(Cfc::Downloader.parse_int(nil))
    assert_nil(Cfc::Downloader.parse_int("--"))
  end

  def test_parse_date_with_valid_date
    assert_equal("2025-12-18", Cfc::Downloader.parse_date("2025-12-18"))
    assert_equal("2019-08-20", Cfc::Downloader.parse_date("2019-08-20"))
  end

  def test_parse_date_with_invalid
    assert_nil(Cfc::Downloader.parse_date(""))
    assert_nil(Cfc::Downloader.parse_date("--"))
    assert_nil(Cfc::Downloader.parse_date(nil))
  end

  def test_clean_name_with_quotes
    assert_equal("Lancman", Cfc::Downloader.clean_name('" Lancman'))
    assert_equal("Kyle", Cfc::Downloader.clean_name('"Kyle'))
  end

  def test_clean_name_with_special_values
    assert_nil(Cfc::Downloader.clean_name("---"))
    assert_nil(Cfc::Downloader.clean_name(""))
  end

  def test_clean_city
    assert_equal("Scarborough", Cfc::Downloader.clean_city('"Scarborough'))
    assert_equal("New York", Cfc::Downloader.clean_city('"New York'))
    assert_nil(Cfc::Downloader.clean_city(""))
  end

  def test_parse_players
    csv_data = <<~CSV
      "CFC#","Expiry","Last","First","Prov","City","Rating","High","Active Rtg","Active High","FIDE Number","FIDE Rating"
      191362,2025-12-18,"---","---","ON",Scarborough",0,0,1092,1,,0
      171117,2019-08-20," Lancman","Kyle","US",New York",1991,1991,1898,1806,75003732,0
    CSV

    players = Cfc::Downloader.parse_players(csv_data)

    assert_equal(2, players.length)
    assert_equal(191_362, players[0][:cfc_id])
    assert_equal(171_117, players[1][:cfc_id])
    assert_equal("Kyle", players[1][:first_name])
  end
end
