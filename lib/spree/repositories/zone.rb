module Spree
  class ZoneRepository
    include Lotus::Repository

    def self.default
      query do
        where(default_tax: true).limit(1)
      end.first
    end
  end
end

mapper = Lotus::Model::Mapper.new do
  collection :zones do
    entity Spree::Zone

    attribute :id,   Integer
    attribute :name, String
    attribute :kind, String
    attribute :default_tax, Boolean
    attribute :members, Array
  end
end

Mutex.new.synchronize do
  mapper.load!
end

Spree::ZoneRepository.adapter = Spree.adapter_class.new(mapper)