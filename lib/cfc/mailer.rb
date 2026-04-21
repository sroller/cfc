# frozen_string_literal: true

require "mail"
require "date"

module Cfc
  module Mailer
    def self.send_mail(recipients, subject, html_body, text_body: nil, from: nil)
      recipients = parse_recipients(recipients)
      return if recipients.empty?

      from ||= ENV.fetch("CFC_MAIL_FROM", "cfc@localhost")

      text_body ||= html_to_text(html_body)

      mail = Mail.new do
        from    from
        to      recipients
        subject subject
        date    Time.now

        text_part do
          body text_body
        end

        html_part do
          content_type "text/html; charset=UTF-8"
          body html_body
        end
      end

      settings = configure_smtp

      mail.delivery_method :smtp, settings
      mail.deliver!

      $stderr.puts "Email sent to #{recipients.join(", ")}"
    rescue StandardError => e
      $stderr.puts "Error sending email: #{e.message}"
      raise
    end

    def self.parse_recipients(recipients_str)
      return [] if recipients_str.nil? || recipients_str.empty?

      recipients_str.split(",").map(&:strip).reject(&:empty?)
    end

    def self.configure_smtp
      smtp_server = ENV.fetch("CFC_SMTP_SERVER", "localhost")
      smtp_port = ENV.fetch("CFC_SMTP_PORT", "25").to_i

      {
        address: smtp_server,
        port: smtp_port
      }
    end

    def self.html_to_text(html)
      # Strip HTML tags and clean up whitespace
      text = html.gsub(/<[^>]+>/, " ")
      text = text.gsub(/&\w+;/, "")
      text = text.gsub(/\s+/, " ").strip
      text
    end
  end
end
