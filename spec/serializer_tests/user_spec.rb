require 'rails_helper'

RSpec.describe User do
  fixtures :users

  
  it "should cache the serializer method and be clearable" do
    user = User.find_by_email('test@test.test')

    expect(user.serializer).to eq(
      {"id"=>1, "email"=>"test@test.test", "first_name"=>"Ben", "last_name"=>"Dana"}
    )

    user.update(first_name: 'Neb')

    expect(User.find_by_email('test@test.test').first_name).to eq('Neb')

    expect(user.serializer).to eq(
      {"id"=>1, "email"=>"test@test.test", "first_name"=>"Ben", "last_name"=>"Dana"}
    )

    user.clear_serializer_cache

    expect(user.serializer).to eq(
      {"id"=>1, "email"=>"test@test.test", "first_name"=>"Neb", "last_name"=>"Dana"}
    )

  end

  it "should have only 2 query key in it's serializer key cache constant" do
    expect(User::SERIALIZER_QUERY_KEYS_CACHE).to eq([:with_vehicle_parts_serializer_query, :serializer_query] )
  end

  it "should attach the inherited serializer method" do
    user = User.find_by_email('test@test.test')

    expect(user.serializer).to eq(
      {"id"=>1, "email"=>"test@test.test", "first_name"=>"Ben", "last_name"=>"Dana"}
    )
  end
end