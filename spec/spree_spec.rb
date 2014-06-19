require 'spec_helper'

describe Spree do
  it "can set the adapter class" do
    Spree.adapter_class = Class.new
  end
end