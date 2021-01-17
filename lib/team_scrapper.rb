require "mechanize"
require "httparty"

class TeamScrapper
  def visit_roster(link)
    agent = Mechanize.new
    begin
      @page = agent.get(link)
    rescue Net::HTTPForbidden
      link = CGI.escape(link)
      HTTParty.get(ENV["LOCAL_HOST"] + "/proxy?uri=#{link}")
    end
  end

  def scrape_players
    active_links = @page.links.find_all.select do |link|
      not_injuried(link) && active_player_link(link)
    end
    parse_names(active_links)
  end

  private

  def not_injuried(link)
    !(link.attributes.parent.first && (link.attributes.parent.first[1] =~ /IR/ || link.attributes.parent.first[1] =~ /G/))
  end

  def active_player_link(link)
    link.href =~ /players\/news/
  end

  def parse_names(links)
    {players: links.map {|link| link.text.delete("\n").delete("\t").gsub(/\s\#\d*/, "") }.uniq}
  end
end
