module Serializer
  class Configuration
    attr_accessor :enable_includes, :default_cache_time, :disable_model_caching, :debug

    def initialize
      @enable_includes = true
      @default_cache_time = 360
      @disable_model_caching = false
      @debug = false
    end
  end
end