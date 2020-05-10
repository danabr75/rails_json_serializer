require 'rails_helper'

RSpec.describe Car do
  fixtures :vehicles, :parts


  it "should have only 1 query key in it's serializer key cache constant" do
    expect(Car::SERIALIZER_QUERY_KEYS_CACHE).to eq([:without_nested_parts_serializer_query])
  end

  it "should have a parent class with 2 query keys in it's serializer key cache constant" do
    expect(Vehicle::SERIALIZER_QUERY_KEYS_CACHE).to eq([:serializer_query, :with_parts_serializer_query, :uncached_test2_serializer_query])
  end

  it "should have access to it's inherited query keys" do
    expect(Car.get_cumulatively_inherited_serializer_query_list).to eq(
      [:without_nested_parts_serializer_query, :serializer_query, :with_parts_serializer_query, :uncached_test2_serializer_query]
    )
  end

  it "should have a parent class with 2 query keys in it's cumulative serializer keys" do
    expect(Vehicle.get_cumulatively_inherited_serializer_query_list).to eq(
      [:serializer_query, :with_parts_serializer_query, :uncached_test2_serializer_query]
    )
  end

  it "should not be cached when cache_for is nil" do
    vehicle = Car.find_by_model("Caraven")
    expect(vehicle).not_to eq(nil)

    expect(vehicle.serializer).to eq({"id"=>1, "make"=>"Dodge", "model"=>"Caraven", "make_and_model"=>"Dodge Caraven"} )

    vehicle.update_column(:make, "Plymouth")

    expect(vehicle.serializer).to eq({"id"=>1, "make"=>"Plymouth", "model"=>"Caraven", "make_and_model"=>"Plymouth Caraven"} )
  end

  it "should not be cached when cache_key is nil" do
    vehicle = Car.find_by_model("Caraven")
    expect(vehicle).not_to eq(nil)

    expect(vehicle.uncached_test2_serializer).to eq({"id"=>1, "make"=>"Dodge", "model"=>"Caraven", "make_and_model"=>"Dodge Caraven"} )

    vehicle.update(make: "Plymouth")

    expect(vehicle.uncached_test2_serializer).to eq({"id"=>1, "make"=>"Plymouth", "model"=>"Caraven", "make_and_model"=>"Plymouth Caraven"} )
  end
end