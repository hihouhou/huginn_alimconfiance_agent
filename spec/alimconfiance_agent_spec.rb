require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::AlimconfianceAgent do
  before(:each) do
    @valid_options = Agents::AlimconfianceAgent.new.default_options
    @checker = Agents::AlimconfianceAgent.new(:name => "AlimconfianceAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
