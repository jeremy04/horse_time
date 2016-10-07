require 'open-uri'
require 'pp'
require 'nokogiri'
require 'byebug'
require 'json'
require 'time'
require 'active_support/core_ext/time'

GAME_LINK_PATTERN = /\/gamecenter\/(?<game_number>[0-9]+)$/

def game_number(row)
  anchors = row.css("a.icon-label-link")
  anchors.each do |a|
    url = a.attribute("href")
    if match = GAME_LINK_PATTERN.match(url)
      return match[:game_number]
    end
  end

  nil
end

def away_team(row)
  # The away team name is contained in a
  # title attribute of an <a> tag
  anchor = row.css(".away a").first
  return if anchor.nil?
  anchor.attribute("title").text
end

def home_team(row)
  # The home team name is contained in a
  # title attribute of the last <a> tag
  anchor = row.css(".home a").first
  return if anchor.nil?
  anchor.attribute("title").text
end

schedule = []
start_date = '2016-10-01'

while start_date != '2017-04-09'
  url = "https://www.nhl.com/schedule/-/ET?lazyloadStart=#{start_date}"
  doc = Nokogiri::HTML(open(url))
   
  tables = doc.css("table.day-table")
  dates = doc.css('.section-subheader').map do |day|
    day = Date.parse(day.content)
    if day.month >=  1 && day.month < 9
      day = day.change(year: 2017)
    end
    day.strftime("%Y-%m-%d") 
  end
  pp dates
  start_date = dates.last

  tables.each_with_index do |table, index|
    rows = table.css("tbody tr")
    rows.each do |row|

      game_attrs = { 
        gameID: game_number(row),
        awayTeam: away_team(row),
        homeTeam: home_team(row),
        date: dates[index]
      }
      pp game_attrs
      game_attrs[:awayTeam].gsub(/(.*?)Canadiens/, "Montreal Canadiens")
      game_attrs[:homeTeam].gsub(/(.*?)Canadiens/, "Montreal Canadiens")
      schedule << game_attrs

    end
  end
end

File.open('schedule.json', 'w') do |file|
  file.write(schedule.uniq.to_json)
end

