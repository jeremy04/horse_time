require 'active_support/core_ext/hash/indifferent_access'

class TeamName
  ABBREV_MAPPING = {
    "ANA" => { fullName: "Anaheim Ducks", franchise_id: 32 },
    "ARI" => { fullName: "Arizona Coyotes", franchise_id: 28 },
    "BOS" => { fullName: "Boston Bruins", franchise_id: 6 },
    "BUF" => { fullName: "Buffalo Sabres", franchise_id: 19 },
    "CGY" => { fullName: "Calgary Flames", franchise_id: 21 },
    "CAR" => { fullName: "Carolina Hurricanes", franchise_id: 26 },
    "CHI" => { fullName: "Chicago Blackhawks", franchise_id: 11 },
    "COL" => { fullName: "Colorado Avalanche", franchise_id: 27 },
    "CBJ" => { fullName: "Columbus Blue Jackets", franchise_id: 36 },
    "DAL" => { fullName: "Dallas Stars", franchise_id: 15 },
    "DET" => { fullName: "Detroit Red Wings", franchise_id: 12 },
    "EDM" => { fullName: "Edmonton Oilers", franchise_id: 25 },
    "FLA" => { fullName: "Florida Panthers", franchise_id: 33 },
    "LAK" => { fullName: "Los Angeles Kings", franchise_id: 14 },
    "MIN" => { fullName: "Minnesota Wild", franchise_id: 37 },
    "MTL" => { fullName: "Montreal Canadiens", franchise_id: 1 },
    "NSH" => { fullName: "Nashville Predators", franchise_id: 34 },
    "NJD" => { fullName: "New Jersey Devils", franchise_id: 23 },
    "NYI" => { fullName: "New York Islanders", franchise_id: 22 },
    "NYR" => { fullName: "New York Rangers", franchise_id: 10 },
    "OTT" => { fullName: "Ottawa Senators", franchise_id: 30 },
    "PHI" => { fullName: "Philadelphia Flyers", franchise_id: 16 },
    "PIT" => { fullName: "Pittsburgh Penguins", franchise_id: 17 },
    "SJS" => { fullName: "San Jose Sharks", franchise_id: 29 },
    "SEA" => { fullName: "Seattle Kraken", franchise_id: 39 },
    "STL" => { fullName: "St. Louis Blues", franchise_id: 18 },
    "TBL" => { fullName: "Tampa Bay Lightning", franchise_id: 31 },
    "TOR" => { fullName: "Toronto Maple Leafs", franchise_id: 5 },
    "VAN" => { fullName: "Vancouver Canucks", franchise_id: 20 },
    "VGK" => { fullName: "Vegas Golden Knights", franchise_id: 38 },
    "WSH" => { fullName: "Washington Capitals", franchise_id: 24 },
    "WPG" => { fullName: "Winnipeg Jets", franchise_id: 35 }
  }.transform_keys(&:upcase).with_indifferent_access



  TEAM_MAPPING = {
    "Anaheim Ducks": { abbrev: "ANA", franchise_id: 32 },
    "Arizona Coyotes": { abbrev: "ARI", franchise_id: 28 },
    "Boston Bruins": { abbrev: "BOS", franchise_id: 6 },
    "Buffalo Sabres": { abbrev: "BUF", franchise_id: 19 },
    "Calgary Flames": { abbrev: "CGY", franchise_id: 21 },
    "Carolina Hurricanes": { abbrev: "CAR", franchise_id: 26 },
    "Chicago Blackhawks": { abbrev: "CHI", franchise_id: 11 },
    "Colorado Avalanche": { abbrev: "COL", franchise_id: 27 },
    "Columbus Blue Jackets": { abbrev: "CBJ", franchise_id: 36 },
    "Dallas Stars": { abbrev: "DAL", franchise_id: 15 },
    "Detroit Red Wings": { abbrev: "DET", franchise_id: 12 },
    "Edmonton Oilers": { abbrev: "EDM", franchise_id: 25 },
    "Florida Panthers": { abbrev: "FLA", franchise_id: 33 },
    "Los Angeles Kings": { abbrev: "LAK", franchise_id: 14 },
    "Minnesota Wild": { abbrev: "MIN", franchise_id: 37 },
    "Montreal Canadiens": { abbrev: "MTL", franchise_id: 1 },
    "Nashville Predators": { abbrev: "NSH", franchise_id: 34 },
    "New Jersey Devils": { abbrev: "NJD", franchise_id: 23 },
    "New York Islanders": { abbrev: "NYI", franchise_id: 22 },
    "New York Rangers": { abbrev: "NYR", franchise_id: 10 },
    "Ottawa Senators": { abbrev: "OTT", franchise_id: 30 },
    "Philadelphia Flyers": { abbrev: "PHI", franchise_id: 16 },
    "Pittsburgh Penguins": { abbrev: "PIT", franchise_id: 17 },
    "San Jose Sharks": { abbrev: "SJS", franchise_id: 29 },
    "Seattle Kraken": { abbrev: "SEA", franchise_id: 39 },
    "St. Louis Blues": { abbrev: "STL", franchise_id: 18 },
    "Tampa Bay Lightning": { abbrev: "TBL", franchise_id: 31 },
    "Toronto Maple Leafs": { abbrev: "TOR", franchise_id: 5 },
    "Vancouver Canucks": { abbrev: "VAN", franchise_id: 20 },
    "Vegas Golden Knights": { abbrev: "VGK", franchise_id: 38 },
    "Washington Capitals": { abbrev: "WSH", franchise_id: 24 },
    "Winnipeg Jets": { abbrev: "WPG", franchise_id: 35 }
}.with_indifferent_access


  def self.get_team_name(abbreviation)
    ABBREV_MAPPING[abbreviation.upcase][:fullName]
  end

  def self.get_franchise(team_name)
    TEAM_MAPPING[team_name][:franchise_id]
  end
end
