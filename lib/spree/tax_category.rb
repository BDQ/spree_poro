module Spree
  class TaxCategory
    include Lotus::Entity
    self.attributes = [:name]
  end
end