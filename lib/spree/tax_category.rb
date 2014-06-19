module Spree
  class TaxCategory
    include Lotus::Entity
    self.attributes = [:name]

    def ==(other)
      id ? super : object_id == other.object_id
    end
  end
end