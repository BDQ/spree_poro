require 'active_support/callbacks'

module Spree
  # Manage (recalculate) item (LineItem or Shipment) adjustments
  class ItemAdjustments
    include ActiveSupport::Callbacks
    define_callbacks :promo_adjustments, :tax_adjustments
    attr_reader :item

    def initialize(item)
      @item = item
    end

    def update
      calculate_adjustments
      update_totals
    end

    def calculate_adjustments
      calculate_promo_total
      calculate_tax_total

      item.adjustment_total = item.promo_total + item.additional_tax_total
    end

    def calculate_promo_total
      promo_total = 0
      run_callbacks :promo_adjustments do
        promo_total = calculate(promo_adjustments)
        unless promo_total == 0
          choose_best_promotion_adjustment
        end
        item.promo_total = best_promotion_adjustment.amount.to_f
      end
    end

    def calculate_tax_total
      included_tax_total = 0
      additional_tax_total = 0
      run_callbacks :tax_adjustments do
        item.included_tax_total = calculate(included_tax_adjustments)
        item.additional_tax_total = calculate(additional_tax_adjustments)
      end
    end

    def update_totals
      # AR update_column call
    end 

    # Picks one (and only one) promotion to be eligible for this item
    # This promotion provides the most discount, and if two promotions
    # have the same amount, then it will pick the latest one.
    def choose_best_promotion_adjustment
      if best_promotion_adjustment
        promotion_adjustments = item.adjustments.select do |adjustment|
          Spree::PromotionAction === adjustment.source
        end

        other_promotions = promotion_adjustments.select do |adjustment|
          adjustment.source != best_promotion_adjustment.source
        end

        other_promotions.each do |adjustment|
          adjustment.eligible = false
        end
      
        best_promotion_adjustment.eligible = true

        best_promotion_adjustment
      end
    end

    def best_promotion_adjustment
      best_adjustment = promo_adjustments.select(&:eligible?).sort do |adjustment_1, adjustment_2|
        adjustment_1.amount <=> adjustment_2.amount
      end.first

      # If none found, return a dummy adjustment
      best_adjustment ||= begin
        adjustment = Spree::Adjustment.new
        adjustment.amount = 0
        adjustment
      end 
    end

    private

    def included_tax_adjustments
      @included_tax_adjustments ||= item.adjustments.select do |adjustment|
        Spree::TaxRate === adjustment.source &&
        adjustment.included
      end
    end

    def additional_tax_adjustments
      @additional_tax_adjustments ||= item.adjustments.select do |adjustment|
        Spree::TaxRate === adjustment.source &&
        !adjustment.included
      end
    end

    def promo_adjustments
      @promo_adjustments ||= item.adjustments.select do |adjustment|
        Spree::PromotionAction === adjustment.source
      end
    end

    def calculate(adjustments)
      adjustments.map(&:update!).compact.inject(&:+).to_f
    end
  end
end