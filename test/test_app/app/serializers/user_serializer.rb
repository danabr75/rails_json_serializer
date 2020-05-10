module UserSerializer
  include ApplicationSerializer

  # Test default

  def with_car_parts_serializer_query opts = {}
    {
      :include => {
        cars: Car.with_parts_serializer_query.merge(as: :cars_with_parts)
      },
      :methods => %w(
        full_name
      ),
      :except => [:first_name, :last_name],
      cache_key: __callee__,
    }
  end
end