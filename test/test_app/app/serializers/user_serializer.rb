module UserSerializer
  include ApplicationRecordSerializer
    def with_vehicle_parts_serializer_query opts = {}
      {
        :include => {
          vehicles: Vehicle.with_parts_serializer_query
        },
        :methods => %w(
          full_name
        ),
        :except => [:first_name, :last_name],
        cache_key: __callee__,
      }
    end

  include Serializer
end