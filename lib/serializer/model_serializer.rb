module ModelSerializer
  # klazz is that class object that included this module
  def self.included klass
    # START CLASS EVAL
    klass.class_eval do


      # I don't think we need to check for classname + serialiers. We are now including via: `include ModelSerializer` in classes
      # Rails 5 has autoloading issues with modules. They will show as not defined, when available.
      if Rails.env.development?
        begin
          "#{klass.name}Serializer".constantize
        rescue NameError => e
        end
      end
      
      if self.const_defined?("#{klass.name}Serializer")
        serializer_klass = "#{klass.name}Serializer".constantize
        serializer_query_names = serializer_klass.public_instance_methods
        if klass.superclass.const_defined?("SERIALIZER_QUERY_KEYS_CACHE")
          self.const_set('SERIALIZER_QUERY_KEYS_CACHE', (serializer_query_names + klass.superclass::SERIALIZER_QUERY_KEYS_CACHE).uniq)
        else
          self.const_set('SERIALIZER_QUERY_KEYS_CACHE', serializer_query_names)
        end
        # Inject class methods, will have access to those queries on the class.
        klass.send(:extend, serializer_klass)

        # Class method to clear the cache of objects without having to instantiate them.
        def self.clear_serializer_cache id_or_ids
          if !id_or_ids.is_a?(Array)
            id_or_ids = [id_or_ids]
          end
          id_or_ids.each do |object_id|
            self::SERIALIZER_QUERY_KEYS_CACHE.each do |query_name|
              cache_key = Serializer.configuration.cache_key.call(self.name, query_name, object_id)
              Rails.logger.debug "(class) CLEARING SERIALIZER CACHE: #{cache_key}" if Serializer.configuration.debug
              Rails.cache.delete(cache_key)
            end
          end
        end

        # no need to define it if inheriting class has defined it OR has been manually overridden.
        # CLASS METHOD - :serializer
        klass.send(:define_singleton_method, :serializer) do |opts = {}|
          # puts "CLASS METHOD - SERIALIZER - OPTS: #{opts.inspect}"
          query = opts[:json_query_override].present? ? self.send(opts[:json_query_override], opts) : serializer_query(opts)
          
          # if as_json arg, then add to as_json query
          if opts[:disable_caching] == true
            query[:disable_caching] = true
          end
          
          if Serializer.configuration.enable_includes && query[:include].present? && !opts[:skip_eager_loading]
            includes(generate_includes_from_json_query(query)).as_json(query)
          else
            # Have to use 'all' gets stack level too deep otherwise. Not sure why.
            all.as_json(query)
          end
        end

        klass.send(:define_singleton_method, :generate_includes_from_json_query) do |options = {}, klass = nil|  
          query_filter = {}
          klass = self if klass.nil?
          if options[:include].present? && !options[:skip_eager_loading]
            options[:include].each do |include_key, include_hash|
              next if include_hash[:skip_eager_loading] == true
              # Will 'next' if there is a scope that takes arguments, an instance-dependent scope.
              # Can't eager load when assocation has a instance condition for it's associative scope.
              # Might not be a real assocation
              next if klass.reflect_on_association(include_key).nil?
              next if klass.reflect_on_association(include_key).scope&.arity&.nonzero?
              query_filter[include_key] = {}
              next if include_hash.none?
              query_filter[include_key] = generate_includes_from_json_query(include_hash, klass.reflect_on_association(include_key).klass)
            end
          end
          # Does not include data, just eager-loads. Useful when methods need assocations, but you don't need association data.
          if options[:eager_include].present?
            options[:eager_include].each do |include_key|
              # Will 'next' if there is a scope that takes arguments, an instance-dependent scope.
              # Can't eager load when assocation has a instance condition for it's associative scope.
              # Might not be a real assocation
              next if klass.reflect_on_association(include_key).nil?
              next if klass.reflect_on_association(include_key).scope&.arity&.nonzero?
              query_filter[include_key] ||= {}
            end
          end
          return query_filter
        end

        klass.send(:define_singleton_method, :as_json_associations_alias_fix) do |options, data, opts = {}|  
          if data
            # Depth is almost purely for debugging purposes
            opts[:depth] ||= 0
            if options[:include].present?
              options[:include].each do |include_key, include_hash|
                # The includes doesn't have to have a hash attached. Skip it if it doesn't.
                next if include_hash.nil?
                data_key = include_key.to_s
                if include_hash[:as].present?
                  if include_hash[:as].to_s == include_key.to_s
                    raise "Serializer: Cannot alias json query association to have the same as the original key; as: #{include_hash[:as].to_s}; original_key: #{include_key.to_s} on self: #{name}"
                  end
                  alias_name = include_hash[:as]
                  data[alias_name.to_s] = data[include_key.to_s]
                  data.delete(include_key.to_s)
                  data_key = alias_name.to_s
                end
                # At this point, the data could be an array of objects, with no as_json options.
                if !data[data_key].is_a?(Array)
                  data[data_key] = as_json_associations_alias_fix(include_hash, data[data_key], {depth: opts[:depth] + 1})
                else
                  data[data_key].each_with_index do |value,i|
                    data[data_key][i] = as_json_associations_alias_fix(include_hash, value, {depth: opts[:depth] + 1})
                  end
                end
              end
            end
          end
          return data
        end

        # no need to define it if inheriting class has defined it OR has been manually overridden.
        # INSTANCE Methods


        klass.send(:define_method, :as_json) do |options = {}|
          # We don't need to run this custom `as_json` multiple times, if defined on inherited class.
          if options[:ran_serialization]
            return super(options)
          end
          options[:ran_serialization] = true

          # Not caching records that don't have IDs.
          if !Serializer.configuration.disable_model_caching && self.id && options[:cache_key].present? && !(options.key?(:cache_for) && options[:cache_for].nil?)
            cache_key = Serializer.configuration.cache_key.call(self.class.name, options[:cache_key], self.id)

            if Rails.cache.exist?(cache_key) && options[:disable_caching] != true
              Rails.logger.debug "Serializer: Cache reading #{cache_key}" if Serializer.configuration.debug
              # Rails.logger.debug(options.inspect) if Serializer.configuration.debug
              outgoing_data = Rails.cache.read(cache_key)
              if (options.key?(:compress) && options[:compress] == true) || (!options.key?(:compress) && Serializer.configuration.compress)
                outgoing_data = Serializer.configuration.decompressor.call(outgoing_data)
              end
              return outgoing_data
            else
              data = super(options)
              data = self.class.as_json_associations_alias_fix(options, data)

              if options[:disable_caching] != true
                # compress data
                cachable_data = data
                if (options.key?(:compress) && options[:compress] == true) || (!options.key?(:compress) && Serializer.configuration.compress)
                  cachable_data = Serializer.configuration.compressor.call(data)
                end
                begin
                    Rails.logger.debug "Serializer: Caching #{cache_key} for #{(options[:cache_for] || Serializer.configuration.default_cache_time)} minutes." if Serializer.configuration.debug
                    Rails.cache.write(cache_key, cachable_data, expires_in: (options[:cache_for] || Serializer.configuration.default_cache_time).minute)
                  rescue Exception => e
                    Rails.logger.error "Serializer: Internal Server Error on #{self.class}#as_json ID: #{self.id} for cache key: #{cache_key}"
                    Rails.logger.error e.class
                    Rails.logger.error e.message
                    Rails.logger.error e.backtrace
                end
              else
                Rails.logger.debug "Serializer: Cache reading/writing for #{cache_key} is disabled" if Serializer.configuration.debug
              end

              return data
            end
          else
            if Serializer.configuration.debug && !Serializer.configuration.disable_model_caching && self.id && options[:cache_key].present? && options.key?(:cache_for) && options[:cache_for].nil?
              Rails.logger.debug "Serializer: Caching #{cache_key} NOT caching due to `cache_for: nil`"
            end
            data = super(options)
            data = self.class.as_json_associations_alias_fix(options, data)
            return data
          end
        end

        # INSTANCE METHOD - :serializer
        if !klass.method_defined?(:serializer)
          klass.send(:define_method, :serializer) do |opts = {}|
            # puts "INSTANCE METHOD - SERIALIZER - OPTS: #{opts.inspect}"
            query = opts[:json_query_override].present? ? self.class.send(opts[:json_query_override], opts) : self.class.serializer_query(opts)
            
            # if as_json arg, then add to as_json query
            if opts[:disable_caching] == true
              query[:disable_caching] = true
            end

            if Serializer.configuration.enable_includes && query[:include].present? && self.class.column_names.include?('id') && self.id.present? && !opts[:skip_eager_loading] && self.respond_to?(:persisted?) && self.persisted?
              # It's an extra SQL call, but most likely worth it to pre-load associations
              self.class.includes(self.class.generate_includes_from_json_query(query)).find(self.id).as_json(query)
            else
              as_json(query)
            end
          end
        end

        # # SHOULD NOT BE OVERRIDDEN.
        klass.send(:define_method, :clear_serializer_cache) do
          if self.class.const_defined?("SERIALIZER_QUERY_KEYS_CACHE")
            self.class::SERIALIZER_QUERY_KEYS_CACHE.each do |query_name|
              cache_key = Serializer.configuration.cache_key.call(self.class.name, query_name, self.id)
              Rails.logger.debug "Serializer: CLEARING CACHE KEY: #{cache_key}" if Serializer.configuration.debug
              Rails.cache.delete(cache_key)
            end
            return true
          else
            # if Serializer.configuration.debug
              Rails.logger.error(
                """
                  ERROR. COULD NOT CLEAR SERIALIZER CACHE FOR: Class #{self.class.name}
                  Serializer: Class #{self.class.name} may not have the serializer module #{self.class.name}Serializer defined.
                  Nor was it defined on an inheriting class.
                """
              )
            # end
            return nil
          end
        end

        serializer_query_names.each do |query_name|
          serializer_name = query_name[/(?<name>.+)_query/, :name]
          if serializer_name.nil?
            Rails.logger.error "Serializer: #{serializer_klass.name} method #{query_name} does not end in '(.+)_query', as is expected of serializers" if Serializer.configuration.debug
            next
          end
          if serializer_name == 'serializer'
            # No longer necessary to add here. We've added them above.
            # klass.send(:define_method, serializer_name) do |opts = {}|    
            #   super({json_query_override: query_name}.merge(opts))
            # end
            # klass.send(:define_singleton_method, serializer_name) do |opts = {}|    
            #   super({json_query_override: query_name}.merge(opts))
            # end
          else
            klass.send(:define_method, serializer_name) do |opts = {}|    
              serializer({json_query_override: query_name}.merge(opts))
            end
            klass.send(:define_singleton_method, serializer_name) do |opts = {}|    
              serializer({json_query_override: query_name}.merge(opts))
            end
          end
        end
      end
    end
    # END CLASS EVAL
  end
end