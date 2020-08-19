class Car < Vehicle
  # include Serializer::Concern
  # include CarSerializer
  extend CarSerializer
  puts "CAR LOAD TIME"
end
