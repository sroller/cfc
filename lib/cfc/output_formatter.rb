# frozen_string_literal: true

require "cgi/escape"
require "date"

module Cfc
  module OutputFormatter
    def self.format(data, format, type:, date_range: nil)
      case format
      when "html"
        send("format_html_#{type}", data, date_range: date_range)
      when "csv"
        send("format_csv_#{type}", data, date_range: date_range)
      else
        nil
      end
    end

    # --- Diff formatters ---

    def self.format_html_diff(changes, date_range: nil)
      date_info = date_range ? " (#{date_range})" : " (#{Date.today})"
      html = +<<~HTML
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><title>Rating Changes#{CGI.escapeHTML(date_info)}</title>
        <style>
          body { font-family: sans-serif; margin: 2em; }
          h1 { color: #333; }
          h2 { color: #555; margin-top: 1.5em; }
          table { border-collapse: collapse; width: 100%; margin-bottom: 1em; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
          th { background-color: #f2f2f2; }
          tr:nth-child(even) { background-color: #f9f9f9; }
          .new { color: green; }
          .removed { color: red; }
          .expired { color: red; }
          .summary { margin-top: 2em; padding: 1em; background: #f5f5f5; }
        </style>
        </head>
        <body>
        <h1>Rating Changes#{CGI.escapeHTML(date_info)}</h1>
      HTML

      if changes[:new].any?
        html += "<h2>New Players: #{changes[:new].count}</h2>\n"
        html += diff_table(changes[:new], :new)
      end

      if changes[:removed].any?
        html += "<h2>Retired Players: #{changes[:removed].count}</h2>\n"
        html += diff_table(changes[:removed], :removed)
      end

      if changes[:changed].any?
        html += "<h2>Changed Players: #{changes[:changed].count}</h2>\n"
        html += changed_table(changes[:changed])
      end

      html += <<~HTML
        <div class="summary">
          <h3>Summary</h3>
          <p>New: #{changes[:new].count}</p>
          <p>Retired: #{changes[:removed].count}</p>
          <p>Changed: #{changes[:changed].count}</p>
        </div>
        </body>
        </html>
      HTML

      html
    end

    def self.diff_table(players, type)
      sort_key = ->(p) { [p[:province] || "", p[:city] || "", p[:last_name] || "", p[:first_name] || ""] }
      html = +"<table><tr><th>CFC ID</th><th>Name</th><th>Location</th><th>Rating</th><th>Active</th><th>Membership</th></tr>\n"

      players.sort_by(&sort_key).each do |p|
        name = "#{p[:first_name]} #{p[:last_name]}"
        location = [p[:city], p[:province]].compact.join(", ")
        expire = display_expire_info(p[:expire_date])
        rating = p[:rating] || 0
        active = p[:active_rating] || 0
        prefix = type == :new ? "+" : "-"
        css_class = type == :new ? "new" : "removed"
        expire_html = expire_html_for(p[:expire_date], expire)
        html += "<tr class=\"#{css_class}\"><td>#{p[:cfc_id]}</td><td>#{prefix} #{CGI.escapeHTML(name)}</td><td>#{CGI.escapeHTML(location)}</td><td>#{rating}</td><td>#{active}</td><td>#{expire_html}</td></tr>\n"
      end

      html += "</table>\n"
    end

    def self.changed_table(changes)
      sort_key = ->(c) { [c[:to][:province] || "", c[:to][:city] || "", c[:to][:last_name] || "", c[:to][:first_name] || ""] }
      html = +"<table><tr><th>CFC ID</th><th>Name</th><th>Location</th><th>Rating</th><th>Active</th><th>Membership</th></tr>\n"

      changes.sort_by(&sort_key).each do |c|
        name = "#{c[:to][:first_name]} #{c[:to][:last_name]}"
        location = [c[:to][:city], c[:to][:province]].compact.join(", ")
        expire = display_expire_info(c[:to][:expire_date])
        rating_change = format_rating_change(c[:from][:rating], c[:to][:rating], c[:rating_changed])
        active_change = format_rating_change(c[:from][:active_rating], c[:to][:active_rating], c[:active_changed])
        expire_html = expire_html_for(c[:to][:expire_date], expire)
        html += "<tr><td>#{c[:cfc_id]}</td><td>#{CGI.escapeHTML(name)}</td><td>#{CGI.escapeHTML(location)}</td><td>#{rating_change}</td><td>#{active_change}</td><td>#{expire_html}</td></tr>\n"
      end

      html += "</table>\n"
    end

    def self.format_csv_diff(changes, date_range: nil)
      lines = []
      date_info = date_range || Date.today.to_s
      lines << "# Rating Changes (#{date_info})"
      sort_key = ->(p) { [p[:province] || "", p[:city] || "", p[:last_name] || "", p[:first_name] || ""] }

      if changes[:new].any?
        lines << "type,cfc_id,first_name,last_name,province,city,rating,active_rating,membership"
        changes[:new].sort_by(&sort_key).each do |p|
          lines << csv_row("new", p[:cfc_id], p[:first_name], p[:last_name], p[:province], p[:city], p[:rating], p[:active_rating], p[:expire_date])
        end
      end

      if changes[:removed].any?
        lines << "type,cfc_id,first_name,last_name,province,city,rating,active_rating,membership"
        changes[:removed].sort_by(&sort_key).each do |p|
          lines << csv_row("removed", p[:cfc_id], p[:first_name], p[:last_name], p[:province], p[:city], p[:rating], p[:active_rating], p[:expire_date])
        end
      end

      if changes[:changed].any?
        lines << "type,cfc_id,first_name,last_name,province,city,from_rating,to_rating,from_active,to_active,membership"
        changes[:changed].sort_by(&sort_key).each do |c|
          lines << csv_row_changed(c)
        end
      end

      lines << ""
      lines << "Summary"
      lines << "new,#{changes[:new].count}"
      lines << "retired,#{changes[:removed].count}" if changes[:removed].any?
      lines << "changed,#{changes[:changed].count}"
      lines.join("\n")
    end

    # --- History formatters ---

    def self.format_html_history(data, date_range: nil)
      player = data[:player]
      history = data[:history]
      name = "#{player["first_name"]} #{player["last_name"]}".strip
      date_info = date_range ? " (#{date_range})" : ""
      html = +<<~HTML
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><title>Rating History - #{CGI.escapeHTML(name)}#{CGI.escapeHTML(date_info)}</title>
        <style>
          body { font-family: sans-serif; margin: 2em; }
          h1 { color: #333; }
          table { border-collapse: collapse; width: 100%; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
          th { background-color: #f2f2f2; }
          tr:nth-child(even) { background-color: #f9f9f9; }
        </style>
        </head>
        <body>
        <h1>Rating History for #{CGI.escapeHTML(name)} (CFC ID: #{player["cfc_id"]})#{CGI.escapeHTML(date_info)}</h1>
        <table>
        <tr><th>Date</th><th>Rating</th><th>Active</th></tr>
      HTML

      history.each do |record|
        rating = record["rating"] || 0
        active = record["active_rating"] || 0
        html += "<tr><td>#{record["rating_date"]}</td><td>#{rating}</td><td>#{active}</td></tr>\n"
      end

      html += <<~HTML
        </table>
        <p>Total records: #{history.length}</p>
        </body>
        </html>
      HTML

      html
    end

    def self.format_csv_history(data, date_range: nil)
      player = data[:player]
      history = data[:history]
      name = "#{player["first_name"]} #{player["last_name"]}".strip
      date_info = date_range ? " (#{date_range})" : ""
      lines = ["# Rating History for #{name} (CFC ID: #{player["cfc_id"]})#{date_info}"]
      lines << "date,rating,active_rating"
      history.each do |record|
        rating = record["rating"] || 0
        active = record["active_rating"] || 0
        lines << "#{record["rating_date"]},#{rating},#{active}"
      end
      lines << ""
      lines << "# Total records: #{history.length}"
      lines.join("\n")
    end

    # --- Show formatters ---

    def self.format_html_show(player, date_range: nil)
      name = "#{player["first_name"]} #{player["last_name"]}".strip
      province = player["province"]
      city = player["city"]
      rating = player["rating"] || 0
      active_rating = player["active_rating"] || 0
      rating_date = player["rating_date"]
      expire_date = display_expire_info(player["expire_date"])
      expire_html = expire_html_for(player["expire_date"], expire_date)
      report_date = date_range || Date.today.to_s

      <<~HTML
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><title>#{CGI.escapeHTML(name)} - Report #{report_date}</title>
        <style>
          body { font-family: sans-serif; margin: 2em; }
          h1 { color: #333; }
          table { border-collapse: collapse; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
          th { background-color: #f2f2f2; width: 150px; }
          .expired { color: red; }
        </style>
        </head>
        <body>
        <h1>Player Information (Report: #{report_date})</h1>
        <table>
        <tr><th>Name</th><td>#{CGI.escapeHTML(name)}</td></tr>
        <tr><th>CFC ID</th><td>#{player["cfc_id"]}</td></tr>
        <tr><th>Province</th><td>#{CGI.escapeHTML(province || "")}</td></tr>
        <tr><th>City</th><td>#{CGI.escapeHTML(city || "")}</td></tr>
        <tr><th>Membership</th><td>#{expire_html}</td></tr>
        <tr><th>Rating (#{rating_date})</th><td>#{rating}</td></tr>
        <tr><th>Active Rating</th><td>#{active_rating}</td></tr>
        </table>
        </body>
        </html>
      HTML
    end

    def self.format_csv_show(player, date_range: nil)
      name = "#{player["first_name"]} #{player["last_name"]}".strip
      report_date = date_range || Date.today.to_s
      lines = ["# Player Information (Report: #{report_date})"]
      lines << "field,value"
      lines << "name,#{name}"
      lines << "cfc_id,#{player["cfc_id"]}"
      lines << "province,#{player["province"]}" if player["province"]
      lines << "city,#{player["city"]}" if player["city"]
      lines << "membership,#{player["expire_date"]}" if player["expire_date"]
      lines << "rating,#{player["rating"] || 0}"
      lines << "active_rating,#{player["active_rating"] || 0}"
      lines << "rating_date,#{player["rating_date"]}" if player["rating_date"]
      lines.join("\n")
    end

    # --- Find formatters ---

    def self.format_html_find(players, date_range: nil)
      report_date = date_range || Date.today.to_s
      html = +<<~HTML
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><title>Search Results - Report #{report_date}</title>
        <style>
          body { font-family: sans-serif; margin: 2em; }
          h1 { color: #333; }
          table { border-collapse: collapse; width: 100%; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
          th { background-color: #f2f2f2; }
          tr:nth-child(even) { background-color: #f9f9f9; }
        </style>
        </head>
        <body>
        <h1>Search Results (Report: #{report_date}, #{players.length} player#{"s" if players.length != 1} found)</h1>
        <table>
        <tr><th>CFC ID</th><th>Name</th><th>Location</th><th>Rating</th><th>Active</th></tr>
      HTML

      players.each do |player|
        name = "#{player["first_name"]} #{player["last_name"]}".strip
        location = [player["city"], player["province"]].compact.join(", ")
        rating = player["rating"] || 0
        active = player["active_rating"] || 0
        html += "<tr><td>#{player["cfc_id"]}</td><td>#{CGI.escapeHTML(name)}</td><td>#{CGI.escapeHTML(location)}</td><td>#{rating}</td><td>#{active}</td></tr>\n"
      end

      html += <<~HTML
        </table>
        </body>
        </html>
      HTML

      html
    end

    def self.format_csv_find(players, date_range: nil)
      report_date = date_range || Date.today.to_s
      lines = ["# Search Results (Report: #{report_date}, #{players.length} player#{"s" if players.length != 1} found)"]
      lines << "cfc_id,first_name,last_name,province,city,rating,active_rating"
      players.each do |player|
        lines << "#{player["cfc_id"]},#{player["first_name"]},#{player["last_name"]},#{player["province"]},#{player["city"]},#{player["rating"] || 0},#{player["active_rating"] || 0}"
      end
      lines.join("\n")
    end

    # --- Helpers ---

    def self.display_expire_info(expire_date)
      return "Unknown" if expire_date.nil? || expire_date.empty?

      require_relative "commands/show"
      if Cfc::Commands::Show.is_life_membership?(expire_date)
        "LIFE"
      else
        expire_date
      end
    end

    def self.expire_html_for(expire_date, display_text)
      return CGI.escapeHTML(display_text) if expire_date.nil? || expire_date.empty?

      require_relative "commands/show"

      # Check for life membership
      begin
        is_life = Cfc::Commands::Show.is_life_membership?(expire_date)
        return CGI.escapeHTML(display_text) if is_life
      rescue ArgumentError, Date::Error
        # If we can't parse the date, just display it
        return CGI.escapeHTML(display_text)
      end

      # Check if the date is in the past (expired)
      begin
        date = Date.parse(expire_date)
        if date < Date.today
          "<span class=\"expired\">#{CGI.escapeHTML(display_text)}</span>"
        else
          CGI.escapeHTML(display_text)
        end
      rescue ArgumentError, Date::Error
        CGI.escapeHTML(display_text)
      end
    end

    def self.format_rating_change(from_val, to_val, changed)
      from = from_val || 0
      to = to_val || 0
      return "#{from}" unless changed

      diff = to - from
      sign = diff > 0 ? "+" : ""
      "#{from} &rarr; #{to} (#{sign}#{diff})"
    end

    def self.csv_row(type, cfc_id, first_name, last_name, province, city, rating, active_rating, expire_date)
      [type, cfc_id, first_name, last_name, province, city, rating || 0, active_rating || 0, expire_date || "Unknown"].map { |v| v.to_s }.join(",")
    end

    def self.csv_row_changed(c)
      [
        "changed",
        c[:cfc_id],
        c[:to][:first_name],
        c[:to][:last_name],
        c[:to][:province],
        c[:to][:city],
        c[:from][:rating] || 0,
        c[:to][:rating] || 0,
        c[:from][:active_rating] || 0,
        c[:to][:active_rating] || 0,
        c[:to][:expire_date] || "Unknown"
      ].map(&:to_s).join(",")
    end
  end
end
