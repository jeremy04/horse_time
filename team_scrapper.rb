require 'mechanize'

class TeamScrapper
  def visit_roster
    agent = Mechanize.new
    @page = agent.get("http://www2.dailyfaceoff.com/teams/lines/36/pittsburgh-penguins")
  end

  def scrape_players
    active_links = @page.links.find_all.select do |link| 
      not_injuried(link) && active_player_link(link)
    end
    parse_names(active_links)
  end

  private

  def not_injuried(link)
    !(link.attributes.parent.first && link.attributes.parent.first[1] =~ /IR/)
  end

  def active_player_link(link)
    link.attributes.first[1] =~ /players\/news/
  end

  def parse_names(links)
    { :players => links.map { |link| link.text.gsub("\n","").gsub("\t","") } }
  end

end
