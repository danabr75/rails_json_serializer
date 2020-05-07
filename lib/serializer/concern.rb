module Serializer
  module Concern
    # ActiveSupport extend src: https://stackoverflow.com/questions/2328984/rails-extending-activerecordbase
    extend ActiveSupport::Concern

    # START MODEL INSTANCE METHODS
    def clear_serializer_cache
      if self.class.const_defined?("SerializerCacheQueryKeys")
        list_of_serializer_query_names = "#{self.class.name}::SerializerCacheQueryKeys".constantize
        list_of_serializer_query_names.each do |query_name|
          cache_key = "#{self.class.name}_____#{query_name}___#{self.id}"
          Rails.logger.info "Serializer: CLEARING CACHE KEY: #{cache_key}" if Serializer.configuration.debug
          Rails.cache.delete(cache_key)
        end
        return true
      else
        if Serializer.configuration.debug
          Rails.logger.info(
            """
              Serializer: Class #{self.class.name} does not have the serializer module #{self.class.name}Serializer defined.
              Nor was it defined on an inheriting class.
            """
          )
        end
        return nil
      end
    end

    def as_json options = {}
      # Not caching records that don't have IDs.
      if !Serializer.configuration.disable_model_caching && self.id && options[:cache_key].present? && !(options.key?(:cache_for) && options[:cache_for].nil?)
        cache_key = "#{self.class.name}_____#{options[:cache_key]}___#{self.id}"
        if Rails.cache.exist?(cache_key)
          Rails.logger.info "Serializer: Cache reading #{cache_key}" if Serializer.configuration.debug
          return Rails.cache.read(cache_key)
        else
          data = super(options)
          data = self.class.as_json_associations_alias_fix(options, data)
          begin
            Rails.logger.info "Serializer: Caching #{cache_key} for #{(options[:cache_for] || Serializer.configuration.default_cache_time)} minutes." if Serializer.configuration.debug
            Rails.cache.write(cache_key, data, expires_in: (options[:cache_for] || Serializer.configuration.default_cache_time).minute)
          rescue Exception => e
            Rails.logger.error "Serializer: Internal Server Error on #{self.class}#as_json ID: #{self.id} for cache key: #{cache_key}"
            Rails.logger.error e.class
            Rails.logger.error e.message
            Rails.logger.error e.backtrace
          end
          return data
        end
      else
        if Serializer.configuration.debug && !Serializer.configuration.disable_model_caching && self.id && options[:cache_key].present? && options.key?(:cache_for) && options[:cache_for].nil?
          Rails.logger.info "Serializer: Caching #{cache_key} NOT caching due to `cache_for: nil`"
        end
        data = super(options)
        data = self.class.as_json_associations_alias_fix(options, data)
        return data
      end
    end

    # Can override the query, using the options. ex: {json_query_override: :tiny_serializer_query}
    def serializer opts = {}
      query = opts[:json_query_override].present? ? self.class.send(opts[:json_query_override], opts) : self.class.serializer_query(opts)
      if Serializer.configuration.enable_includes && query[:include].present? && self.class.column_names.include?('id') && self.id.present? && !opts[:skip_eager_loading] && self.respond_to?(:persisted?) && self.persisted?
        # It's an extra SQL call, but most likely worth it to pre-load associations
        self.class.includes(self.class.generate_includes_from_json_query(query)).find(self.id).as_json(query)
      else
        as_json(query)
      end
    end
    # END MODEL INSTANCE METHODS

    class_methods do
       # START MODEL CLASS METHODS
      def inherited subclass
        if subclass.const_defined?("#{subclass.name}Serializer")
          serializer_klass = "#{subclass.name}Serializer".constantize

          if serializer_klass.class == Module
            if !serializer_klass.const_defined?("SerializerMethods")
              serializer_klass.const_set('SerializerMethods', Module.new {})
            end

            serializer_klass.public_instance_methods.each do |query_name|
              serializer_name = query_name[/(?<name>.+)_query/, :name]
              if serializer_name.nil?
                Rails.logger.info "Serializer: #{serializer_klass.name} method #{query_name} does not end in '(.+)_query', as is expected of serializers" if Serializer.configuration.debug
                next
              end
              # Skip if chosen to override it.
              next if serializer_klass.respond_to?(serializer_name)
              if serializer_name == 'serializer'
                serializer_klass::SerializerMethods.send(:define_method, serializer_name) do |opts = {}|    
                  super({json_query_override: query_name}.merge(opts))
                end
              else
                serializer_klass::SerializerMethods.send(:define_method, serializer_name) do |opts = {}|    
                  serializer({json_query_override: query_name}.merge(opts))
                end
              end
            end

            # Inject instance methods
            subclass.send(:include, serializer_klass::SerializerMethods)
            # Inject class methods
            subclass.send(:extend, serializer_klass::SerializerMethods)
            # Inject class methods that has queries
            subclass.send(:extend, serializer_klass)
            # Injecting the Serializer Methods as a namespaced class of the rails class, so we can have
            #   access to the list of methods to clear their cache.
            #   'Class Name + Serializer' does not work with inheritence.
            subclass.const_set('SerializerCacheQueryKeys', serializer_klass.public_instance_methods)
          else
            Rails.logger.info "Serializer: #{serializer_klass.name} was not a Module as expected" if Serializer.configuration.debug
          end
        end
        super(subclass)
      end

      # Can override the query, using the options. ex: {json_query_override: :tiny_children_serializer_query}
      def serializer opts = {}
        query = opts[:json_query_override].present? ? self.send(opts[:json_query_override], opts) : serializer_query(opts)
        if Serializer.configuration.enable_includes && query[:include].present? && !opts[:skip_eager_loading]
          includes(generate_includes_from_json_query(query)).as_json(query)
        else
          # Have to use 'all' gets stack level too deep otherwise. Not sure why.
          all.as_json(query)
        end
      end

      def as_json_associations_alias_fix options, data, opts = {}
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

      def generate_includes_from_json_query options = {}, klass = nil
        query_filter = {}
        klass = self if klass.nil?
        if options[:include].present? && !options[:skip_eager_loading]
          options[:include].each do |include_key, include_hash|
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
        return query_filter
      end
      # END MODEL CLASS METHODS

    end
  end
end