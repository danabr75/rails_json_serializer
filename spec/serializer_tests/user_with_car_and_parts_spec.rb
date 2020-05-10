require 'rails_helper'

RSpec.describe User do
  fixtures :users

  it "should load in fixtures" do
    expect(User.count).to eq(1)
  end
end