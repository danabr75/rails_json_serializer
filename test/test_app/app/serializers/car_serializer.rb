module CarSerializer

  def without_nested_parts_serializer_query opts = {}
    {
      :include => {
        parts: Part.shallow_serializer_query
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