module Spree
  class Zone
    include Lotus::Entity

    self.attributes = :name, :members, :default_tax, :kind

    def initialize(*args)
      @members ||= []
      super
    end

    def self.default_tax
      Spree::ZoneRepository.default
    end

    def contains?(target)
      return false if kind == 'state' && target.kind == 'country'
      return false if members.empty? || target.members.empty?

      if kind == target.kind
        return false if target.members.any? { |target_zoneable| !members.include?(target_zoneable) }
      else
        return false if target.members.any? { |target_state| !members.include?(target_state.country) }
      end
      true
    end
  end
end