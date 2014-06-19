require 'pry'
require 'rspec'
require 'simplecov'
SimpleCov.start

require 'spree'
require 'lotus/utils/string'

module Spree
  module TestHelpers
    def create(type, attributes)
      klass_name = Lotus::Utils::String.new(type).classify
      klass = Spree.const_get(klass_name)
      klass_repository = Spree.const_get("#{klass_name}Repository")
      record = klass.new(attributes)
      klass_repository.persist(record)
    end
  end
end

RSpec.configure do |c| 
  c.include Spree::TestHelpers

  c.before do
    Spree::Data.clear
    Spree::ZoneRepository.clear
    Spree::TaxRateRepository.clear
    Spree::TaxCategoryRepository.clear
  end

end