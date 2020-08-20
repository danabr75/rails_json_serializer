module PartSerializer
  include ApplicationRecordSerializer
  MAX_NESTED_DEPTH = 5

    def serializer_query opts = {}, depth = 0
      query = {
        :include => {
        },
      }
      if depth < MAX_NESTED_DEPTH
        query[:include][:parts] = Part.serializer_query(opts, depth + 1)
      else
      end
      return query
    end

    def shallow_serializer_query opts = {}
      {
        :include => {
        },
      }
    end


  include Serializer
end