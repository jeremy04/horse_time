require_relative '../lib/players_validator'
require 'minitest/autorun'

describe PlayersValidator do
  before do
    players =  [{"name" => "rawr","horses" => {"horse_team" => ["C. Atkinson","S. Jones"],"other_team" => ["P. Subban","D. Smith-Pelly"]}},{"name" => "woo","horses" => {"horse_team" => ["B. Dubinsky","B. Saad"],"other_team" => ["T. Mitchell","A. Galchenyuk"]}}]
    @validator = PlayersValidator.new(players, 2)
  end

  describe "valid?" do
    it "returns true with non-dup horses" do
      @validator.valid?.must_equal true
    end

    it "returns false with dup horses single player" do
      players =  [{"name" => "rawr","horses" => {"horse_team" => ["S. Jones","S. Jones"],"other_team" => ["P. Subban","D. Smith-Pelly"]}},{"name" => "woo","horses" => {"horse_team" => ["B. Dubinsky","B. Saad"],"other_team" => ["T. Mitchell","A. Galchenyuk"]}}]
      @validator = PlayersValidator.new(players, 2)
      @validator.valid?.must_equal false
    end

    it "returns true with too many horses" do
      players =  [{"name" => "rawr","horses" => {"horse_team" => ["C. Atkinson","S. Jones","woo"],"other_team" => ["P. Subban","D. Smith-Pelly"]}},{"name" => "woo","horses" => {"horse_team" => ["B. Dubinsky","B. Saad"],"other_team" => ["T. Mitchell","A. Galchenyuk"]}}]
      @validator = PlayersValidator.new(players, 2)
      @validator.valid?.must_equal false
    end

    it "returns false with dup horses multiple player" do
      players =  [{"name" => "rawr","horses" => {"horse_team" => ["S. Jones","C. Atkinson"],"other_team" => ["P. Subban","D. Smith-Pelly"]}},{"name" => "woo","horses" => {"horse_team" => ["S. Jones","B. Saad"],"other_team" => ["T. Mitchell","A. Galchenyuk"]}}]
      @validator = PlayersValidator.new(players, 2)
      @validator.valid?.must_equal false
    end
  end

end