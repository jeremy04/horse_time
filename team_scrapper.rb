require 'mechanize'
require 'pp'
class Scores

  def goals
    agent = Mechanize.new
    page = agent.get("http://www.nicetimeonice.com/api/seasons/20152016/games/")

    json = JSON.parse(page.content)
    json = json.select { |x| x["awayTeam"] == "Pittsburgh Penguins" || x["homeTeam"] == "Pittsburgh Penguins" }
    json = json.select { |x| Time.now.to_date == Date.parse(x["date"])  }.first
    
    begin
      agent = Mechanize.new
      page = agent.get("http://www.nhl.com/gamecenter/en/icetracker?id=#{json["gameID"]}")
    rescue Mechanize::ResponseCodeError
      return {:goals => [], :assists => [] }
    end
    doc = Nokogiri::HTML(page.body)  
    skaters = doc.css(".skaters tbody tr").children.map { |x| x.text }.each_slice(9).to_a
    goals = skaters.select { |s| s[3].to_i > 0 }.map { |x| [x[1],x[3].to_i] }
    assists =  skaters.select { |s| s[4].to_i > 0 }.map { |x| [x[1],x[3].to_i] }
    {:goals => goals, :assists => assists }
  end

end


class AwayTeamScrapper
  def determine_team
    schedule = {}
    agent = Mechanize.new
    page = agent.get("http://www2.dailyfaceoff.com/teams/schedule/36/pittsburgh-penguins/")
    doc = Nokogiri::HTML(page.body)
    doc.css("#matchups_container table tr").each do |x| 
      schedule[Date.parse(x.children[1].text)] = [x.children[3].text, x.children[5].text]
    end
    future = schedule.select { |k,v| Time.now.to_date == k }
    future.first[1].delete("Pittsburgh Penguins")
    team = future.first[1].first
 
    page = agent.get("http://www2.dailyfaceoff.com/teams/")
    doc = Nokogiri::HTML(page.body)
    link = doc.css("#matchups_container a").map { |x| x.attributes["href"].value }.select { |x| x =~ /#{team.gsub(" ","-").downcase}/  }
    link.first
  end

end

class TeamScrapper
  def visit_roster(link)
    agent = Mechanize.new
    @page = agent.get(link)
  end

  def scrape_players
    active_links = @page.links.find_all.select do |link| 
      not_injuried(link) && active_player_link(link)
    end
    parse_names(active_links)
  end

  private

  def not_injuried(link)
    !(link.attributes.parent.first && (link.attributes.parent.first[1] =~ /IR/ || link.attributes.parent.first[1] =~ /G/)  ) 
  end

  def active_player_link(link)
    link.attributes.first[1] =~ /players\/news/
  end

  def parse_names(links)
    { :players => links.map { |link| link.text.gsub("\n","").gsub("\t","") } }
  end

end
