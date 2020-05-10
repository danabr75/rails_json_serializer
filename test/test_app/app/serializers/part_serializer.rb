module PartSerializer
  def serializer_query opts = {}
    {
      :include => {
        parts: Part.serializer_query
      },
    }
  end

  def shallow_serializer_query opts = {}
    {
      :include => {
      },
    }
  end
end