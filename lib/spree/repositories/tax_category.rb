module Spree
  class TaxCategoryRepository
    include Lotus::Repository
  end
end

mapper = Lotus::Model::Mapper.new do
  collection :tax_categories do
    entity Spree::TaxCategory

    attribute :id,   Integer
    attribute :name, String
  end
end

Mutex.new.synchronize do
  mapper.load!
end

Spree::TaxCategoryRepository.adapter = Spree.adapter_class.new(mapper)