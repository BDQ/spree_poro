require 'pry'
require 'rspec'
require 'simplecov'
SimpleCov.start

require 'spree'

module Spree
  module TestHelpers
    def create_zone(attributes)
      zone = Spree::Zone.new(attributes)
      Spree::ZoneRepository.persist(zone)
    end
  end
end

RSpec.configure do |c| 
  c.include Spree::TestHelpers

  c.before do
    Spree::Data.clear
    Spree::ZoneRepository.clear
  end

end