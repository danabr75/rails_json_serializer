class Car < Vehicle
  # include Serializer::Concern
  # include CarSerializer
  # extend CarSerializer
  include CarSerializer
  puts "CAR LOAD TIME"
end
