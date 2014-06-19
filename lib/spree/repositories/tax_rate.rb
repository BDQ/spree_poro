module Spree
  class TaxRateRepository
    include Lotus::Repository

    def self.match(order)
      # Rates are excluded based on currency because of this:
      # If you have a product priced in $10 USD, then it should be taxed at the USD rate.
      # If someone buys that $10 USD product and they're not from a US tax zone, no tax rate applies.
      # If that product is sold at $10 AUD instead, then the AUD tax rate should apply for that item, if there is one.
      results = query do
        where(currency: order.currency)
      end

      results.all.select do |rate|
        (rate.zone.contains?(order.tax_zone) || rate.zone == Zone.default_tax)
      end
    end
  end
end

mapper = Lotus::Model::Mapper.new do
  collection :tax_rates do
    entity Spree::TaxRate

    attribute :id,   Integer
    attribute :name, String
    attribute :amount, Float
    attribute :included_in_price, Boolean
    attribute :currency, String
    attribute :zone_id, String
    attribute :tax_category_id, String
  end
end

Mutex.new.synchronize do
  mapper.load!
end

Spree::TaxRateRepository.adapter = Lotus::Model::Adapters::MemoryAdapter.new(mapper)