module VehicleSerializer
  include ApplicationRecordSerializer
    def serializer_query opts = {}
      {
        :include => {
        },
        :methods => %w(
          make_and_model
        ),
        :except => %w(
          user_id
        ),
        cache_key: __callee__,
        cache_for: nil,
      }
    end

    def with_parts_serializer_query opts = {}
      {
        :include => {
          parts: Part.serializer_query
        },
        :methods => %w(
        ),
        :except => %w(
          user_id
        ),
        cache_key: __callee__,
      }
    end

    def uncached_test2_serializer_query opts = {}
      {
        :include => {
        },
        :methods => %w(
          make_and_model
        ),
        :except => %w(
          user_id
        ),
      }
    end

  include Serializer
end