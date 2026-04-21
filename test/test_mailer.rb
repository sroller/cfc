# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/cfc/mailer"

module Cfc
  class TestMailer < Minitest::Test
    def test_parse_recipients_single
      recipients = Mailer.parse_recipients("user@example.com")
      assert_equal ["user@example.com"], recipients
    end

    def test_parse_recipients_multiple
      recipients = Mailer.parse_recipients("user1@example.com,user2@example.com,user3@example.com")
      assert_equal ["user1@example.com", "user2@example.com", "user3@example.com"], recipients
    end

    def test_parse_recipients_with_spaces
      recipients = Mailer.parse_recipients("user1@example.com, user2@example.com , user3@example.com")
      assert_equal ["user1@example.com", "user2@example.com", "user3@example.com"], recipients
    end

    def test_parse_recipients_nil
      recipients = Mailer.parse_recipients(nil)
      assert_equal [], recipients
    end

    def test_parse_recipients_empty
      recipients = Mailer.parse_recipients("")
      assert_equal [], recipients
    end

    def test_parse_recipients_with_empty_items
      recipients = Mailer.parse_recipients("user1@example.com,,user2@example.com")
      assert_equal ["user1@example.com", "user2@example.com"], recipients
    end

    def test_html_to_text_basic
      html = "<html><body><h1>Hello World</h1><p>Some text</p></body></html>"
      text = Mailer.html_to_text(html)
      assert_equal "Hello World Some text", text
    end

    def test_html_to_text_with_entities
      html = "<p>Rating &amp; Score</p>"
      text = Mailer.html_to_text(html)
      assert_equal "Rating Score", text
    end

    def test_html_to_text_with_tables
      html = "<table><tr><td>Name</td><td>Rating</td></tr><tr><td>John</td><td>1500</td></tr></table>"
      text = Mailer.html_to_text(html)
      assert_includes text, "Name"
      assert_includes text, "Rating"
      assert_includes text, "John"
      assert_includes text, "1500"
    end

    def test_html_to_text_empty
      text = Mailer.html_to_text("")
      assert_equal "", text
    end

    def test_html_to_text_whitespace
      text = Mailer.html_to_text("   \n\n  \t  ")
      assert_equal "", text
    end

    def test_configure_smtp_defaults
      original_server = ENV["CFC_SMTP_SERVER"]
      original_port = ENV["CFC_SMTP_PORT"]
      ENV.delete("CFC_SMTP_SERVER")
      ENV.delete("CFC_SMTP_PORT")

      settings = Mailer.configure_smtp
      assert_equal "localhost", settings[:address]
      assert_equal 25, settings[:port]
    ensure
      ENV["CFC_SMTP_SERVER"] = original_server
      ENV["CFC_SMTP_PORT"] = original_port
    end

    def test_configure_smtp_custom
      original_server = ENV["CFC_SMTP_SERVER"]
      original_port = ENV["CFC_SMTP_PORT"]
      ENV["CFC_SMTP_SERVER"] = "smtp.example.org"
      ENV["CFC_SMTP_PORT"] = "587"

      settings = Mailer.configure_smtp
      assert_equal "smtp.example.org", settings[:address]
      assert_equal 587, settings[:port]
    ensure
      ENV["CFC_SMTP_SERVER"] = original_server
      ENV["CFC_SMTP_PORT"] = original_port
    end

    def test_send_mail_no_recipients
      capture_io do
        result = Mailer.send_mail("", "Test", "<html></html>")
        assert_nil result
      end
    end

    def test_send_mail_smtp_error
      original_server = ENV["CFC_SMTP_SERVER"]
      original_port = ENV["CFC_SMTP_PORT"]
      ENV["CFC_SMTP_SERVER"] = "invalid.host.that.does.not.exist"
      ENV["CFC_SMTP_PORT"] = "25"

      assert_raises do
        capture_io do
          Mailer.send_mail("user@example.com", "Test", "<html><body>Test</body></html>")
        end
      end
    ensure
      ENV["CFC_SMTP_SERVER"] = original_server
      ENV["CFC_SMTP_PORT"] = original_port
    end
  end
end
