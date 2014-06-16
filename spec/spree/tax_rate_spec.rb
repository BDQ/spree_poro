  require 'spec_helper'

module Spree
  describe TaxRate do
    let!(:order) do
      order = Spree::Order.new
      order.currency = 'USD'
      order
    end

    let!(:usa_zone) do
      zone = Spree::Zone.new
      zone.name = 'USA'
      usa = Spree::Country.new
      zone.members << usa
      zone.default_tax = true
      zone.kind = 'country'
      zone
    end

    let!(:france_zone) do
      zone = Spree::Zone.new
      zone.name = 'France'
      france = Spree::Country.new
      zone.members << france
      zone.default_tax = false
      zone.kind = 'country'
      zone
    end

    let!(:aus_zone) do
      zone = Spree::Zone.new
      zone.name = 'Australia'
      australia = Spree::Country.new
      zone.members << australia
      zone.default_tax = false
      zone.kind = 'country'
      zone
    end

    let!(:canada) do
      canada = Spree::Country.new
      canada.name = 'Canada'
      canada
    end

    let!(:bc) do
      bc = Spree::State.new
      bc.name = 'bc'
      bc.country = canada
      bc
    end

    let!(:canada_zone) do
      zone = Spree::Zone.new
      zone.name = 'Canada'
      zone.members << canada
      zone.default_tax = false
      zone.kind = 'country'
      zone
    end

    let!(:bc_zone) do
      zone = Spree::Zone.new
      zone.name = 'BC'
      zone.members << bc
      zone.default_tax = false
      zone.kind = 'state'
      zone
    end

    let!(:clothing_category) do
      tax_category = Spree::TaxCategory.new
      tax_category.name = "Clothing"
      tax_category
    end

    let!(:food_category) do
      tax_category = Spree::TaxCategory.new
      tax_category.name = "Food"
      tax_category
    end

    let!(:usa_tax_rate) do
      tax_rate = Spree::TaxRate.new
      tax_rate.name = "USA 10%"
      tax_rate.included_in_price = false
      tax_rate.amount = 0.1
      tax_rate.currency = "USD"
      tax_rate.tax_category = clothing_category
      clothing_category.tax_rates << tax_rate
      tax_rate.zone = usa_zone
      tax_rate
    end

    let!(:france_tax_rate) do
      tax_rate = Spree::TaxRate.new
      tax_rate.name = "EUR 5%"
      tax_rate.included_in_price = true
      tax_rate.amount = 0.05
      tax_rate.currency = "FRF"
      tax_rate.tax_category = clothing_category
      clothing_category.tax_rates << tax_rate
      tax_rate.zone = france_zone
      tax_rate
    end

    let!(:canada_tax_rate) do
      tax_rate = Spree::TaxRate.new
      tax_rate.name = "5% PST"
      tax_rate.included_in_price = true
      tax_rate.amount = 0.05
      tax_rate.currency = "CAD"
      tax_rate.tax_category = clothing_category
      clothing_category.tax_rates << tax_rate
      tax_rate.zone = canada_zone
      tax_rate
    end


    let!(:bc_tax_rate) do
      tax_rate = Spree::TaxRate.new
      tax_rate.name = "7% PST"
      tax_rate.included_in_price = true
      tax_rate.amount = 0.07
      tax_rate.currency = "CAD"
      tax_rate.tax_category = clothing_category
      clothing_category.tax_rates << tax_rate
      tax_rate.zone = bc_zone
      tax_rate
    end

    context "match" do
      context "with USA zone as default tax zone" do
        before do
          usa_zone.default_tax = true
        end

        it "picks USA tax rates" do
          rates = Spree::TaxRate.match(order)
          expect(rates).to include(usa_tax_rate)
          expect(rates).to_not include(france_tax_rate)
        end
      end

      context "based on order tax zone" do
        before do
          order.tax_zone = france_zone
        end

        it "returns both rates" do
          rates = Spree::TaxRate.match(order)
          expect(rates).to include(usa_tax_rate)
          expect(rates).to_not include(france_tax_rate)
        end
      end
    end

    context ".adjust" do
      context "with line items" do
        before do
          product = Spree::Product.new
          variant = Spree::Variant.new
          variant.product = product
          product.master = variant
          product.tax_category = clothing_category

          line_item = Spree::LineItem.new
          line_item.price = 10
          line_item.variant = variant
          line_item.order = order
          order.line_items << line_item
        end

        it "adds 10% default tax for the order's line item" do
          Spree::TaxRate.adjust(order, order.line_items)
          expect(order.line_items.first.adjustments.count).to eq(1)
          adjustment = order.line_items.first.adjustments.first
          expect(adjustment.amount).to eq(1) # = 10% of $10.
          expect(adjustment.included).to eq(false)
        end

        it "bases the 10% off the discounted amount" do
          order.line_items.first.promo_total = -5
          Spree::TaxRate.adjust(order, order.line_items)
          expect(order.line_items.first.adjustments.count).to eq(1)
          adjustment = order.line_items.first.adjustments.first
          expect(adjustment.amount).to eq(0.5) # = 10% of $5.
          expect(adjustment.included).to eq(false)
        end

        context "with a line item with a different tax category" do
          before do
            order.line_items.first.variant.product.tax_category = food_category
          end

          it "does not apply an adjustment" do
            Spree::TaxRate.adjust(order, order.line_items)
            expect(order.line_items.first.adjustments.count).to eq(0)
          end
        end

        context "in the French zone" do
          before do
            order.tax_zone = france_zone
            order.currency = 'FRF'
          end

          it "includes 5% tax for the order's line item" do
            Spree::TaxRate.adjust(order, order.line_items)
            expect(order.line_items.first.adjustments.count).to eq(1)
            adjustment = order.line_items.first.adjustments.first
            expect(adjustment.amount.round(2)).to eq(0.48) # 10 - (10 / 105%) = 0.476, but we round to 2.
            expect(adjustment.included).to eq(true)
          end
        end

        context "in the BC zone" do
          before do
            order.tax_zone = bc_zone
            order.currency = "CAD"
          end

          # See https://github.com/spree/spree/issues/4318#issuecomment-34601738
          # This is the only instance I know of in the world where two taxes can apply at once.
          it "applies both the GST (5%) and PST (7%) taxes" do
            Spree::TaxRate.adjust(order, order.line_items)
            item = order.line_items.first
            expect(item.adjustments.count).to eq(2)
            inclusive = order.line_items.first.adjustments.map(&:included)
            expect(inclusive.all?).to eq(true)

            amounts = item.adjustments.map(&:amount).sort
            expect(amounts.first.round(2)).to eq(0.45)
            expect(amounts.last.round(2)).to eq(0.63)
            expect((amounts.inject(&:+) + item.pre_tax_amount).round(2)).to eq(item.discounted_amount)
          end
        end

        context "with an order for an AU customer" do
          before do
            order.tax_zone = aus_zone
          end
          
          # Tax rate is additional, so it makes no sense to refund a tax that hasn't been applied yet!
          it "applies no tax adjustment at all" do
            Spree::TaxRate.adjust(order, order.line_items)
            expect(order.line_items.first.adjustments.count).to eq(0)
          end
        end

        context "with French zone as the default" do
          before do
            usa_zone.default_tax = false
            france_zone.default_tax = true
          end

          context "with an order for a USA customer" do
            before do
              order.tax_zone = usa_zone
            end

            it "applies the 10% tax from the US" do
              Spree::TaxRate.adjust(order, order.line_items)
              expect(order.line_items.first.adjustments.count).to eq(1)
              adjustment = order.line_items.first.adjustments.first
              expect(adjustment.amount).to eq(1) #10% of $10.
              expect(adjustment.included).to eq(false)
            end
          end

          context "with an order for a AUS customer" do
            before do
              order.tax_zone = aus_zone
              order.currency = 'FRF'
            end

            it "applies the 5% tax refund from EUR" do
              Spree::TaxRate.adjust(order, order.line_items)
              expect(order.line_items.first.adjustments.count).to eq(1)
              adjustment = order.line_items.first.adjustments.first
              expect(adjustment.amount.round(2)).to eq(-0.48) # 10 - ( 10 / (1 + 5%  ) ) = 0.476, but we round to 2.
              expect(adjustment.included).to eq(false)
            end

            context "when order uses AUD" do
              before do
                order.currency = 'AUD'
              end

              it "does not apply a refund" do
                Spree::TaxRate.adjust(order, order.line_items)
                expect(order.line_items.first.adjustments.count).to eq(0)
              end 
            end
          end
        end
      end

      context "with shipments" do
        before do
          item = Spree::Shipment.new
          item.tax_category = clothing_category
          item.cost = 10
          item.discounted_cost = 10
          item.order = order
          order.shipments << item
        end

        it "adds 10% default tax for the order's shipment" do
          Spree::TaxRate.adjust(order, order.shipments)
          shipment = order.shipments.first
          expect(shipment.adjustments.count).to eq(1)
          adjustment = shipment.adjustments.first
          expect(adjustment.amount).to eq(1) # = 10% of $10.
          expect(adjustment.included).to eq(false)
        end

        it "bases the 10% off the discounted amount" do
          shipment = order.shipments.first
          shipment.discounted_cost = 5
          Spree::TaxRate.adjust(order, order.shipments)
          expect(shipment.adjustments.count).to eq(1)
          adjustment = shipment.adjustments.first
          expect(adjustment.amount).to eq(0.5) # = 10% of $5.
          expect(adjustment.included).to eq(false)
        end

        context "in the French zone" do
          before do
            order.tax_zone = france_zone
            order.currency = 'FRF'
          end

          it "includes 5% tax for the order's shipment" do
            Spree::TaxRate.adjust(order, order.shipments)
            shipment = order.shipments.first
            expect(shipment.adjustments.count).to eq(1)
            adjustment = shipment.adjustments.first
            expect(adjustment.amount.round(2)).to eq(0.48) # 10 - (10 / 105%) = 0.476, but we round to 2.
            expect(adjustment.included).to eq(true)
          end
        end
      end
    end 
  end
end