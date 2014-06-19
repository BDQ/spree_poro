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
            currency: 'USD',
            tax_category_id: clothing_category.id,
            zone_id: usa_zone.id
          )
        end

        let!(:france_tax_rate) do
          create(:tax_rate,
            name: 'EUR 5%',
            currency: 'FRF',
            tax_category_id: clothing_category.id,
            zone_id: usa_zone.id
          )
        end

        let!(:canada) { Spree::Country.new }

        let!(:canada_zone) do
          create(:zone, name: 'Canada', members: [canada], default_tax: false, kind: 'country')
        end

        let!(:bc_zone) do
          bc = Spree::State.new
          bc.country = canada

          create(:zone, name: 'Canada', members: [bc], default_tax: false, kind: 'state')
        end

        let!(:canada_tax_rate) do
          create(:tax_rate,
            name: '5% GST',
            currency: 'CAD',
            tax_category_id: clothing_category.id,
            zone_id: canada_zone.id
          )
        end

        let!(:bc_tax_rate) do
          create(:tax_rate,
            name: '7% PST',
            currency: 'CAD',
            tax_category_id: clothing_category.id,
            zone_id: bc_zone.id
          )
        end

        context "with USA zone as default tax zone" do
          before do
            usa_zone.default_tax = true
          end

          it "picks USA tax rates" do
            rates = Spree::TaxRateRepository.match(order)
            expect(rates.count).to eq(1)
            expect(rates).to include(usa_tax_rate)
          end
        end

        context "for French orders" do
          before do
            order.tax_zone = france_zone
            order.currency = 'FRF'
          end

          it "returns the french tax rate" do
            rates = Spree::TaxRateRepository.match(order)
            expect(rates.count).to eq(1)
            expect(rates).to include(france_tax_rate)
          end
        end

        context "for Canadian orders" do
          before do
            order.currency = 'CAD'
          end

          context "in BC" do
            before do
              order.tax_zone = bc_zone
            end

            it "returns the canadian and BC rates" do
              rates = Spree::TaxRateRepository.match(order)
              expect(rates.count).to eq(2)
              expect(rates).to include(canada_tax_rate)
              expect(rates).to include(bc_tax_rate)
            end
          end

          context "not in BC" do
            before do
              order.tax_zone = canada_zone
            end

            it "returns the canadian tax rate" do
              rates = Spree::TaxRateRepository.match(order)
              expect(rates.count).to eq(1)
              expect(rates).to include(canada_tax_rate)
            end
          end
        end

        context "for Australian orders" do
          before do
            order.currency = 'USD'
            order.tax_zone = create(:zone, name: 'Australia')
          end

          it "returns the US tax for a potential refund" do
            rates = Spree::TaxRateRepository.match(order)
            expect(rates.count).to eq(1)
            expect(rates).to include(usa_tax_rate)
          end          
        end
      end
    end
  end
end