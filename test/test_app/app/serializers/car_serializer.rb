module CarSerializer
 # def CarSerializer.included(klass)
 #  klass.include VehicleSerializer
 # end
  include VehicleSerializer

  def without_nested_parts_serializer_query opts = {}
    {
      :include => {
        # parts: Part.shallow_serializer_query
      },
      :methods => %w(
      ),
      :except => %w(
        user_id
      ),
      cache_key: __callee__,
    }
  end
end