module Spree
  class Product
    include Lotus::Entity

    self.attributes = [:tax_category_id]

    def tax_category
      @tax_category ||= Spree::TaxCategoryRepository.find(tax_category_id)
    end
  end
end