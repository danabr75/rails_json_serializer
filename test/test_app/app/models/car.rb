class Car < Vehicle
  # include Serializer::Concern
  # include CarSerializer
  # extend CarSerializer
  include ModelSerializer
  puts "CAR LOAD TIME"
end
