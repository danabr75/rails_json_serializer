require "zlib"

module Serializer
  class Configuration
    attr_accessor :enable_includes, :default_cache_time, :disable_model_caching, :debug, :cache_key
    attr_accessor :compress, :compressor, :decompressor

    def initialize
      @enable_includes = true
      @default_cache_time = 360
      @disable_model_caching = false
      @debug = false
      @compress = false
      @cache_key = Proc.new { |class_name, query_name, object_id| "#{class_name}_____#{query_name}___#{object_id}" }
      @compressor = Proc.new { |incoming_data| Base64.encode64(Zlib::Deflate.deflate(incoming_data.to_json)) }

      # have to use 'temp_val', or else there's an issue with the libraries. Won't work as a 1-liner
      @decompressor = Proc.new do |outgoing_data|
        temp_val1 = Base64.decode64(outgoing_data)
        temp_val2 = Zlib::Inflate.inflate(temp_val1)
        JSON.parse(temp_val2)
      end

    end
  end
end