require 'spec_helper'

module Spree
  module Repositories
    describe TaxRateRepository do
      context "match" do
        let!(:order) do
          order = Spree::Order.new
          order.currency = 'USD'
          order
        end
        
        let!(:usa_zone) do
          usa = Spree::Country.new
          create(:zone, name: 'USA', members: [usa], default_tax: true, kind: 'country')
        end

        let!(:france_zone) do
          france = Spree::Country.new
          create(:zone, name: 'France', members: [france], default_tax: false, kind: 'country')
        end

        let!(:clothing_category) do
          create(:tax_category, name: "Clothing")
        end

        let!(:usa_tax_rate) do
          create(:tax_rate,
            name: 'USA 10%',
            included_in_price: false,
            amount: 0.1,
            currency: 'USD',
            tax_category_id: clothing_category.id,
            zone_id: usa_zone.id
          )
        end

        let!(:france_tax_rate) do
          create(:tax_rate,
            name: 'EUR 5%',
            included_in_price: false,
            amount: 0.05,
            currency: 'FRF',
            tax_category_id: clothing_category.id,
            zone_id: usa_zone.id
          )
        end

        context "with USA zone as default tax zone" do
          before do
            usa_zone.default_tax = true
          end

          it "picks USA tax rates" do
            rates = Spree::TaxRateRepository.match(order)
            expect(rates).to include(usa_tax_rate)
            expect(rates).to_not include(france_tax_rate)
          end
        end

        context "based on order tax zone" do
          before do
            order.tax_zone = france_zone
          end

          it "returns the french" do
            rates = Spree::TaxRateRepository.match(order)
            expect(rates).to include(usa_tax_rate)
            expect(rates).to_not include(france_tax_rate)
          end
        end
      end
    end
  end
end