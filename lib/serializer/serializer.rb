module Serializer
  DELETE_MATCHED_SUPPORTED_CACHE_TYPES = [:memory_store, :file_store]
  # extend ActiveSupport::Concern
  # def serializer_query opts = {}
  #   {
  #     include: {
  #     },
  #     methods: %w(),
  #     cache_key: __callee__,
  #   }
  # end
  # START MODEL INSTANCE METHODS HERE
  def clear_serializer_cache
    if self.class.const_defined?("SERIALIZER_QUERY_KEYS_CACHE")
      list_of_serializer_query_names = "#{self.class.name}::SERIALIZER_QUERY_KEYS_CACHE".constantize
      list_of_serializer_query_names.each do |query_name|
        cache_key = "#{self.class.name}_____#{query_name}___#{self.id}"
        Rails.logger.info "Serializer: CLEARING CACHE KEY: #{cache_key}" if Serializer.configuration.debug
        Rails.cache.delete(cache_key)
      end
      return true
    else
      Rails.logger.error(
        """
          ERROR. COULD NOT CLEAR SERIALIZER CACHE FOR: Class #{self.class.name}
          Serializer: Class #{self.class.name} may not have the serializer module #{self.class.name}Serializer defined.
          Nor was it defined on an inheriting class.
        """
      )
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

  def serializer opts = {}
    query = opts[:json_query_override].present? ? self.class.send(opts[:json_query_override], opts) : self.class.serializer_query(opts)
    if Serializer.configuration.enable_includes && query[:include].present? && self.class.column_names.include?('id') && self.id.present? && !opts[:skip_eager_loading] && self.respond_to?(:persisted?) && self.persisted?
      # It's an extra SQL call, but most likely worth it to pre-load associations
      self.class.includes(self.class.generate_includes_from_json_query(query)).find(self.id).as_json(query)
    else
      as_json(query)
    end
  end

  # END MODEL INSTANCE METHODS HERE
  # extend ActiveSupport::Concern
  # included do
  #   puts "GOT HERE included do: #{self.name}"
  # end

  # def self.included(serializer_klass)
  #   puts "self.included(serializer_klass)"
  #   puts "KLASS INCLUDED: #{serializer_klass}"
  #   # if klass.const_defined?("#{klass.name}Serializer")
  #   #   puts "GOT HERE"
  #   #   serializer_klass = "#{klass.name}Serializer".constantize
  #   #   puts "KEYS: #{serializer_klass.singleton_methods}"
  #   # end
  #   serializer_klass.include(ClassMethods)
  #   # serializer_klass.include(serializer_klass::Queries)
  #   # puts "serializer_klass.public_instance_methods: #{serializer_klass.public_instance_methods}"
  #   # serializer_klass.const_set('SERIALIZER_QUERY_KEYS_CACHE', serializer_klass.public_instance_methods)
  #   # serializer_klass.class_eval do
  #   #   include Helper
  #   #   include InstanceMethods
  #   # end
  #   # serializer_klass.send(:define_method, :get_cumulatively_inherited_serializer_query_list) do |opts = {}|    
  #   #   if defined?(super)
  #   #     return (klass::SERIALIZER_QUERY_KEYS_CACHE + superclass.get_cumulatively_inherited_serializer_query_list).uniq
  #   #   else
  #   #     return klass::SERIALIZER_QUERY_KEYS_CACHE
  #   #   end
  #   # end
  #   # serializer_klass.define_singleton_method(:serializer_query_keys_cache) do
  #   #   'test hah ah ah'
  #   # end
  # end
  extend ActiveSupport::Concern
  included do
    klass = self
    puts "GOT HERE4: #{name}"
    # def inherited klass
    # self.include(ClassMethods)
  end

  module ClassMethods
    # START MODEL CLASS METHODS HERE
    # if DELETE_MATCHED_SUPPORTED_CACHE_TYPES.include?(Rails.configuration.cache_store)
    #   def clear_serializer_cache
    #     self.get_cumulatively_inherited_serializer_query_list.each do |query_name|
    #       cache_key_prefix = /#{self.name}_____#{query_name}___(\d+)/
    #       Rails.logger.info "Serializer: CLEARING CACHE KEY Prefix: #{cache_key_prefix}" if Serializer.configuration.debug
    #       Rails.cache.delete_matched(cache_key_prefix)
    #     end
    #     return true
    #   end
    # else
    #   def clear_serializer_cache
    #     Rails.logger.error "Not supported by rails cache store: #{Rails.configuration.cache_store}. Supported: #{DELETE_MATCHED_SUPPORTED_CACHE_TYPES}"
    #     return false
    #   end
    # end

    # def serializer_query_keys_cache
    #   # # class is CAr here.
    #   return self.public_instance_methods
    # end

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
    # END MODEL CLASS METHODS HERE
  end
end