ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/rails"
require "factory_bot_rails"
require "database_cleaner/active_record"
require "mocha/minitest"

# Configure FactoryBot - clear any existing definitions first
FactoryBot.reload

# Configure DatabaseCleaner
DatabaseCleaner.strategy = :transaction
DatabaseCleaner.clean_with(:truncation)

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Using FactoryBot instead of fixtures

  # Include FactoryBot methods
  include FactoryBot::Syntax::Methods

  # Setup database cleaner
  setup do
    DatabaseCleaner.start
  end

  teardown do
    DatabaseCleaner.clean
  end

  # Add more helper methods to be used by all tests here...
end

class ActionDispatch::IntegrationTest
  # Include FactoryBot methods for integration tests
  include FactoryBot::Syntax::Methods
end
