require 'mechanize'

class AwayTeamScrapper
  def determine_team
    # agent = Mechanize.new
    # page = agent.get("http://www.nicetimeonice.com/api/seasons/20152016/games/")
    # json = JSON.parse(page.content)
    # json = json.select { |x| x["awayTeam"] == "Pittsburgh Penguins" || x["homeTeam"] == "Pittsburgh Penguins" }
    # json = json.select { |x| Time.now.to_date <= Date.parse(x["date"])  }

    # if json["awayTeam"] != "Pittsburgh Penguins"
    #   team = json["awayTeam"]
    # else
    #   team = json["homeTeam"]
    # end
    # team

    schedule = {}
    agent = Mechanize.new
    page = agent.get("http://www2.dailyfaceoff.com/teams/schedule/36/pittsburgh-penguins/")
    doc = Nokogiri::HTML(page.body)
    doc.css("#matchups_container table tr").each do |x| 
      schedule[Date.parse(x.children[1].text)] = [x.children[3].text, x.children[5].text]
    end
    future = schedule.select { |k,v| Time.now.to_date <= k }
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
