require_relative 'serializer/model_serializer'
Dir[File.join(Rails.root, 'app', 'serializers', '**', '*.rb')].each {|file| require file }
require_relative 'serializer/configuration'

module Serializer
  # config src: http://lizabinante.com/blog/creating-a-configurable-ruby-gem/
  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset
    @configuration = Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end

# include the extension 
# ActiveRecord::Base.send(:include, Serializer::Concern)