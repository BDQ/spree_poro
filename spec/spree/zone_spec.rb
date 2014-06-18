require 'spec_helper'

module Spree
  describe Zone do
    let!(:canada) do
      country = Spree::Country.new
      country.name = 'Canada'
      country
    end

    let!(:bc) do
      state = Spree::State.new
      state.name = 'BC'
      state.country = canada
      state
    end

    let!(:canada_zone) do
      zone = Spree::Zone.new
      zone.name = 'Canada'
      zone.kind = 'country'
      zone.members << canada
      zone
    end

    let!(:bc_zone) do
      zone = Spree::Zone.new
      zone.name = 'BC'
      zone.kind = 'state'
      zone.members << bc
      zone
    end

    context "#contains?" do
      it "Canada zone contains Canada" do
        expect(canada_zone.contains?(canada_zone)).to be true
      end
      
      it "Canada zone contains BC" do
        expect(canada_zone.contains?(bc_zone)).to be true
      end
    end
  end
end
