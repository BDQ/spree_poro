module Spree
  class ProductRepository
    include Lotus::Repository
  end
end

mapper = Lotus::Model::Mapper.new do
  collection :products do
    entity Spree::Product

    attribute :id,   Integer
  end
end

Mutex.new.synchronize do
  mapper.load!
end

Spree::ProductRepository.adapter = Lotus::Model::Adapters::MemoryAdapter.new(mapper)