require 'securerandom'

module SecureRandom::RNG
  def self.rand(max)
    SecureRandom.random_number(max)
  end
end