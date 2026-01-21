# typed: false
# frozen_string_literal: true

require 'arctic'
require 'climate_control'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clean up test environment variables after each test
  config.after do
    ['ARCTIC_TEST_VAR', 'ARCTIC_TEST_VAR2', 'TEMP_VAR', 'TEST_KEY'].each do |key|
      ENV.delete(key)
    end
  end
end
