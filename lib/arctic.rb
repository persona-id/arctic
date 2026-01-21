# typed: false
# frozen_string_literal: true

module Arctic
  VERSION = "0.1.0"
end

# Load the compiled C extension
# The extension defines the Arctic module and all its methods
begin
  require 'arctic/arctic'
rescue LoadError => e
  # Provide helpful error message if extension not compiled
  raise LoadError, 'Could not load arctic extension. ' \
                   "Original error: #{e.message}"
end
