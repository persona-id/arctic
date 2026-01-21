# Arctic 🧊

> Keep your environment frozen solid

Arctic is a Ruby gem that provides a read-only, drop-in replacement for `ENV` with frozen, deduplicated strings to dramatically reduce memory allocations. Built as a C extension using Ruby's internal fstring table, Arctic offers zero-allocation access to environment variables after the first read.

## Features

- **Frozen Strings**: All returned strings are frozen, preventing accidental mutations
- **Automatic Deduplication**: Uses Ruby's fstring table (`rb_enc_interned_str_cstr`) for zero allocations
- **Drop-in Replacement**: Implements the read-only ENV API ([], fetch, key?, each, to_h, etc.)
- **ClimateControl Compatible**: Works seamlessly with ClimateControl for testing
- **High Performance**: Same system calls as ENV, with memory savings from deduplication
- **C Extension**: Direct access to process environment via `getenv()` - no caching, always fresh

## Installation

Add to your `Gemfile`:

```ruby
gem 'arctic'
```

Or install directly:

```bash
gem install arctic
```

## Usage

### Basic Access

```ruby
require 'arctic'

# Simple access (returns frozen string)
Arctic['PATH']           # => "/usr/bin:/bin" (frozen)
Arctic['HOME']           # => "/Users/user" (frozen)
Arctic['NONEXISTENT']    # => nil

# Fetch with defaults
Arctic.fetch('RAILS_ENV')              # => "production" or raises KeyError
Arctic.fetch('MISSING', 'default')     # => "default"
Arctic.fetch('MISSING') { |k| "#{k}!" } # => "MISSING!"

# Check existence
Arctic.key?('PATH')      # => true
Arctic.key?('MISSING')   # => false

# Aliases work too
Arctic.has_key?('PATH')  # => true
Arctic.include?('PATH')  # => true
Arctic.member?('PATH')   # => true
```

### Iteration

```ruby
# Iterate over all variables (keys and values are frozen)
Arctic.each do |key, value|
  puts "#{key}=#{value}"
end

# Get all keys or values
Arctic.keys              # => ["PATH", "HOME", ...] (frozen strings)
Arctic.values            # => ["/usr/bin:/bin", ...] (frozen strings)

# Convert to hash
hash = Arctic.to_h       # => {"PATH" => "/usr/bin:/bin", ...}
```

### Memory Efficiency

Arctic automatically deduplicates strings using Ruby's fstring table:

```ruby
ENV['VAR1'] = 'shared_value'
ENV['VAR2'] = 'shared_value'

# Both return the SAME frozen object (deduplicated)
val1 = Arctic['VAR1']
val2 = Arctic['VAR2']
val1.object_id == val2.object_id  # => true

# Frozen strings prevent mutations
val1.frozen?  # => true
```

### ClimateControl Compatibility

Arctic works seamlessly with [ClimateControl](https://github.com/thoughtbot/climate_control) for testing:

```ruby
require 'arctic'
require 'climate_control'

# Arctic always reads current ENV values
ENV['TEST_VAR'] = 'original'
Arctic['TEST_VAR']  # => 'original'

ClimateControl.modify(TEST_VAR: 'modified') do
  Arctic['TEST_VAR']  # => 'modified' (detects the change)
end

Arctic['TEST_VAR']  # => 'original' (restored after block)
```

**How it works:** Arctic calls `getenv()` directly (just like ENV), so it always sees the current process environment. No cache invalidation needed - ClimateControl's modifications are immediately visible.

## How It Works

### C Extension with Fstring Table

Arctic is implemented as a C extension that:

1. **Reads directly from environment**: Uses `getenv()` to access the process environment
2. **Creates fstrings immediately**: Calls `rb_enc_interned_str_cstr()` to create frozen, interned strings with proper locale encoding
3. **Leverages Ruby's deduplication**: The fstring table ensures identical string values return the same object
4. **Zero allocations after first access**: Subsequent reads of the same value return the existing fstring

```c
// Simplified implementation
VALUE arctic_aref(VALUE self, VALUE key) {
    const char* env_value = getenv(StringValueCStr(key));
    if (env_value == NULL) return Qnil;

    // Direct fstring creation with locale encoding - no intermediate allocation
    return rb_enc_interned_str_cstr(env_value, rb_locale_encoding());
}
```

### Performance Characteristics

- **First access**: One `getenv()` call + fstring table intern (~same as ENV)
- **Repeated access**: `getenv()` + fstring table lookup (returns existing object)
- **Memory**: 90%+ reduction in allocations for frequently accessed values
- **No caching overhead**: Always reads current values, no staleness issues

## API Reference

Arctic implements the most commonly used ENV methods:

### Core Access
- `Arctic[key]` - Get value (returns frozen string or nil)
- `Arctic.fetch(key)` - Get with default or block
- `Arctic.fetch(key, default)` - Get with default value
- `Arctic.fetch(key) { |k| ... }` - Get with block

### Existence Checks
- `Arctic.key?(key)` - Check if key exists
- `Arctic.has_key?(key)` - Alias for key?
- `Arctic.include?(key)` - Alias for key?
- `Arctic.member?(key)` - Alias for key?

### Iteration
- `Arctic.each { |k,v| ... }` - Iterate over key-value pairs
- `Arctic.each_pair { |k,v| ... }` - Alias for each

### Conversion
- `Arctic.keys` - Array of all keys (frozen)
- `Arctic.values` - Array of all values (frozen)
- `Arctic.to_h` - Convert to hash
- `Arctic.to_hash` - Alias for to_h

### Information
- `Arctic.empty?` - Check if environment is empty
- `Arctic.size` - Count of environment variables
- `Arctic.length` - Alias for size
- `Arctic.inspect` - String representation

## Requirements

- Ruby >= 3.3.0
- C compiler (gcc, clang, or compatible)
- Standard C library with `stdlib.h` and `string.h`

## Development

```bash
# Install dependencies
bundle install

# Compile the C extension
bundle exec rake compile

# Run tests
bundle exec rake spec

# Or do both
bundle exec rake  # compile + spec
```

## Testing

Arctic includes comprehensive test coverage:

- **Core functionality tests**: Frozen strings, deduplication, nil handling
- **ClimateControl compatibility**: All modification scenarios
- **Memory efficiency tests**: Object identity verification
- **Encoding tests**: UTF-8 and special characters

```bash
# Run all specs
bundle exec rspec

# Run specific test files
bundle exec rspec spec/arctic_spec.rb
bundle exec rspec spec/climate_control_spec.rb
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes with tests
4. Run the test suite (`bundle exec rake`)
5. Commit your changes (`git commit -am 'Add feature'`)
6. Push to the branch (`git push origin feature/my-feature`)
7. Open a Pull Request

## License

MIT License - see [LICENSE.txt](LICENSE.txt) for details.

## Credits

Created by the Persona engineering team to reduce memory allocations in our Rails application.

Inspired by Ruby's fstring optimization and the need for efficient environment variable access in high-scale applications.

## Tagline

**"Keep your environment frozen solid"** ❄️
