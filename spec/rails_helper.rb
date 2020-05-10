ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
require File.expand_path('../../test/test_app/config/environment', __FILE__)
require 'rspec/rails'
require 'database_cleaner'
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

if Rails.configuration.database_configuration[Rails.env]['database'] == ':memory:'
  puts "creating sqlite in memory database"
  ActiveRecord::Base.establish_connection(Rails.env.to_sym)
  ActiveRecord::Schema.verbose = false
  load "#{Rails.root}/db/schema.rb"
end

# Load in Fixtures in Rails console (^ Run the load schema commands as well)
# require "rake"
# TestApp::Application.load_tasks
# Rake::Task['db:fixtures:load'].reenable
# Rake::Task['db:fixtures:load'].invoke


RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = File.expand_path('../../test/test_app/test/fixtures', __FILE__)
  # config.global_fixtures = :all
  # config.use_transactional_tests = true

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # config.include FactoryGirl::Syntax::Methods
  # config.include Devise::Test::ControllerHelpers, type: :controller
  # config.before(:suite) do
  #   DatabaseCleaner.clean_with(:truncation)
  # end
  # config.before(:each) do
  #   DatabaseCleaner.strategy = :transaction
  # end
  # config.before(:each, js: true) do
  #   DatabaseCleaner.strategy = :truncation
  # end
  # config.before(:each) do
  #   DatabaseCleaner.start
  # end
  # config.after(:each) do
  #   DatabaseCleaner.clean
  # end
  # config.before(:all) do
  #   DatabaseCleaner.start
  # end
  # config.after(:all) do
  #   DatabaseCleaner.clean
  # end
  config.infer_spec_type_from_file_location!
end