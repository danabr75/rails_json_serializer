module PartSerializer
  extend ApplicationSerializer
  MAX_NESTED_DEPTH = 5

  def serializer_query opts = {}, depth = 0
    query = {
      :include => {
      },
    }
    if depth < MAX_NESTED_DEPTH
      query[:include][:parts] = Part.serializer_query(opts, depth + 1)
    end
    return query
  end

  def shallow_serializer_query opts = {}
    {
      :include => {
      },
    }
  end
end