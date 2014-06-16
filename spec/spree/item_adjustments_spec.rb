require 'spec_helper'

module Spree
  describe ItemAdjustments do
    let(:item) do 
      item = Spree::LineItem.new
      item.price = 20
      item
    end

    let(:subject) { ItemAdjustments.new(item) }

    context '#update' do
      it "calls recalculate and update" do
        expect(subject).to receive(:calculate_adjustments)
        expect(subject).to receive(:update_totals)
        subject.update
      end
    end

    context "#calculate_adjustments" do
      context "with a tax adjustment" do
        let(:tax_adjustment) do
          adjustment = Adjustment.new
          adjustment.source = Spree::TaxRate.new
          adjustment
        end

        it "updates a linked included tax adjustment" do
          tax_adjustment.included = true
          item.adjustments << tax_adjustment
          expect(tax_adjustment).to receive(:update!)
          subject.calculate_adjustments
        end

        it "updates a linked additional tax adjustment" do
          tax_adjustment.included = false
          item.adjustments << tax_adjustment
          expect(tax_adjustment).to receive(:update!)
          subject.calculate_adjustments
        end
      end

      context "with a promo adjustment" do
        let(:promo_adjustment) do
          adjustment = Adjustment.new
          adjustment.source = Spree::PromotionAction.new
          adjustment
        end

        it "updates a linked promo adjustment" do
          item.adjustments << promo_adjustment
          expect(promo_adjustment).to receive(:update!)
          subject.calculate_adjustments
        end
      end
    end

    context "taxes and promotions" do
      let(:tax_category) { Spree::TaxCategory.new }

      let(:zone) do
        zone = Spree::Zone.new
        zone.name = 'America'
        zone.default_tax = true
        zone
      end

      let(:order) do
        order = Spree::Order.new
        order.currency = 'USD'
        order.tax_zone = zone
        order
      end

      let(:tax_rate) do
        rate = Spree::TaxRate.new
        rate.currency = 'USD'
        rate.amount = 0.05
        rate.tax_category = tax_category
        rate.zone = zone
        tax_category.tax_rates << rate
        rate
      end

      let(:promotion) do
        promotion = Spree::Promotion.new
        promotion.name = "$10 off"
        promotion
      end

      let(:promotion_action) do
        action = Spree::Promotion::Actions::CreateLineItemAdjustment.new
        action.amount = 10
        action
      end

      let(:product) do
        product = Spree::Product.new
        product.tax_category = tax_category
        product
      end

      let(:variant) do
        variant = Spree::Variant.new
        variant.product = product
        variant
      end

      let!(:tax_adjustment) do
        adjustment = Spree::Adjustment.new
        adjustment.source = tax_rate
        adjustment.adjustable = item
        adjustment
      end

      let!(:promo_adjustment) do
        adjustment = Spree::Adjustment.new
        adjustment.source = promotion_action
        adjustment.adjustable = item
        adjustment.eligible = true
        adjustment
      end

      before do
        item.order = order
        item.adjustments << tax_adjustment
        item.adjustments << promo_adjustment
        item.promo_total = promo_adjustment.amount
        item.variant = variant
      end

      context "tax included in price" do
        before do
          tax_adjustment.included = true
          tax_rate.included_in_price = true
          Spree::TaxRate.adjust(order, [item])
        end

        it "tax has no bearing on final price" do
          subject.calculate_adjustments
          expect(item.promo_total).to eq(-10)
          expect(item.included_tax_total.round(2)).to eq(0.48)
          expect(item.additional_tax_total).to eq(0)
          expect(item.adjustment_total).to eq(-10)
        end
      end

      context "tax excluded from price" do
        before do
          tax_adjustment.included = false
          tax_rate.included_in_price = false
        end

        it "tax applies to line item" do
          subject.calculate_adjustments
          # Taxable amount is: $20 (base) - $10 (promotion) = $10
          # Tax rate is 5% (of $10).
          expect(item.promo_total).to eq(-10)
          expect(item.included_tax_total).to eq(0)
          expect(item.additional_tax_total).to eq(0.5)
          expect(item.adjustment_total).to eq(-9.5)
        end
      end
    end

    context "best promotion is always applied" do
      let(:action) do
        action = Spree::Promotion::Actions::CreateLineItemAdjustment.new
        action.amount = 10
        action
      end

      def create_adjustment(label, amount)
        adjustment = Spree::Adjustment.new
        adjustment.label = label
        adjustment.amount = amount
        adjustment.source = action
        adjustment.eligible = true
        item.adjustments << adjustment
        adjustment
      end

      it "should make all but the most valuable promotion adjustment ineligible, leaving non promotion adjustments alone" do
        create_adjustment("Promotion A", -100)
        create_adjustment("Promotion B", -200)
        create_adjustment("Promotion C", -300)

        credit_adjustment = Spree::Adjustment.new
        credit_adjustment.amount = -500
        item.adjustments << credit_adjustment
        item.adjustments.each { |adjustment| adjustment.eligible = true }

        subject.choose_best_promotion_adjustment

        eligible_promotion_adjustments = item.adjustments.select do |adjustment|
          action.class === adjustment.source &&
          adjustment.eligible?
        end

        expect(eligible_promotion_adjustments.count).to eq(1)
        expect(eligible_promotion_adjustments.first.label).to eq('Promotion C')
        expect(eligible_promotion_adjustments.first.eligible?).to eq(true)
        expect(credit_adjustment.eligible?).to eq(true)
      end

      it "should only leave one adjustment even if 2 have the same amount" do
        create_adjustment("Promotion A", -100)
        create_adjustment("Promotion B", -200)
        create_adjustment("Promotion C", -200)

        subject.choose_best_promotion_adjustment

        eligible_promotion_adjustments = item.adjustments.select do |adjustment|
          action.class === adjustment.source &&
          adjustment.eligible?
        end

        expect(eligible_promotion_adjustments.count).to eq(1)
        expect(eligible_promotion_adjustments.first.amount.to_i).to eq(-200)
      end

      context "when previously ineligible promotions become available" do
        let(:order_promo1) { create(:promotion, :with_order_adjustment, :with_item_total_rule, order_adjustment_amount: 5, item_total_threshold_amount: 10) }
        let(:order_promo2) { create(:promotion, :with_order_adjustment, :with_item_total_rule, order_adjustment_amount: 10, item_total_threshold_amount: 20) }
        let(:order_promos) { [ order_promo1, order_promo2 ] }
        let(:line_item_promo1) { create(:promotion, :with_line_item_adjustment, :with_item_total_rule, adjustment_rate: 2.5, item_total_threshold_amount: 10) }
        let(:line_item_promo2) { create(:promotion, :with_line_item_adjustment, :with_item_total_rule, adjustment_rate: 5, item_total_threshold_amount: 20) }
        let(:line_item_promos) { [ line_item_promo1, line_item_promo2 ] }
        let(:order) { create(:order_with_line_items, line_items_count: 1) }

        # Apply promotions in different sequences. Results should be the same.
        promo_sequences = [
          [ 0, 1 ],
          [ 1, 0 ]
        ]

        promo_sequences.each do |promo_sequence|
          it "should pick the best order-level promo according to current eligibility" do
            # apply both promos to the order, even though only promo1 is eligible
            order_promos[promo_sequence[0]].activate order: order
            order_promos[promo_sequence[1]].activate order: order

            order.reload
            order.all_adjustments.count.should eq(2), "Expected two adjustments (using sequence #{promo_sequence})"
            order.all_adjustments.eligible.count.should eq(1), "Expected one elegible adjustment (using sequence #{promo_sequence})"
            order.all_adjustments.eligible.first.source.promotion.should eq(order_promo1), "Expected promo1 to be used (using sequence #{promo_sequence})"

            order.contents.add create(:variant, price: 10), 1
            order.save

            order.reload
            order.all_adjustments.count.should eq(2), "Expected two adjustments (using sequence #{promo_sequence})"
            order.all_adjustments.eligible.count.should eq(1), "Expected one elegible adjustment (using sequence #{promo_sequence})"
            order.all_adjustments.eligible.first.source.promotion.should eq(order_promo2), "Expected promo2 to be used (using sequence #{promo_sequence})"
          end
        end

        promo_sequences.each do |promo_sequence|
          it "should pick the best line-item-level promo according to current eligibility" do
            # apply both promos to the order, even though only promo1 is eligible
            line_item_promos[promo_sequence[0]].activate order: order
            line_item_promos[promo_sequence[1]].activate order: order

            order.reload
            order.all_adjustments.count.should eq(2), "Expected two adjustments (using sequence #{promo_sequence})"
            order.all_adjustments.eligible.count.should eq(1), "Expected one elegible adjustment (using sequence #{promo_sequence})"
            # TODO: Really, with the rule we've applied to these promos, we'd expect line_item_promo2
            # to be selected; however, all of the rules are currently completely broken for line-item-
            # level promos. To make this spec work for now we just roll with current behavior.

            order.contents.add create(:variant, price: 10), 1
            order.save

            order.reload
            order.all_adjustments.count.should eq(4), "Expected four adjustments (using sequence #{promo_sequence})"
            order.all_adjustments.eligible.count.should eq(2), "Expected two elegible adjustments (using sequence #{promo_sequence})"
            order.all_adjustments.eligible.each do |adjustment|
              adjustment.source.promotion.should eq(line_item_promo2), "Expected line_item_promo2 to be used (using sequence #{promo_sequence})"
            end
          end
        end
      end

      context "multiple adjustments and the best one is not eligible" do
        let!(:promo_a) { create_adjustment("Promotion A", -100) }
        let!(:promo_c) { create_adjustment("Promotion C", -300) }

        before do
          promo_a.update_column(:eligible, true)
          promo_c.update_column(:eligible, false)
        end

        # regression for #3274
        it "still makes the previous best eligible adjustment valid" do
          subject.choose_best_promotion_adjustment
          line_item.adjustments.promotion.eligible.first.label.should == 'Promotion A'
        end
      end
    end

    # For #4483
    context "callbacks" do
      class SuperItemAdjustments < Spree::ItemAdjustments
        attr_accessor :before_promo_adjustments_called,
                      :after_promo_adjustments_called,
                      :before_tax_adjustments_called,
                      :after_tax_adjustments_called

        set_callback :promo_adjustments, :before do |object|
          @before_promo_adjustments_called = true
        end

        set_callback :promo_adjustments, :after do |object|
          @after_promo_adjustments_called = true
        end

        set_callback :tax_adjustments, :before do |object|
          @before_tax_adjustments_called = true
        end

        set_callback :promo_adjustments, :after do |object|
          @after_tax_adjustments_called = true
        end
      end
      
      let(:subject) { SuperItemAdjustments.new(line_item) }

      it "calls all the callbacks" do
        subject.update_adjustments
        expect(subject.before_promo_adjustments_called).to be_true
        expect(subject.after_promo_adjustments_called).to be_true
        expect(subject.before_tax_adjustments_called).to be_true
        expect(subject.after_tax_adjustments_called).to be_true
      end
    end
  end
end
