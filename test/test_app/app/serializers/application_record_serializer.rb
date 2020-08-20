module ApplicationRecordSerializer
  def serializer_query opts = {}
    {
      include: {
      },
      methods: %w(),
      cache_key: __callee__,
    }
  end
end