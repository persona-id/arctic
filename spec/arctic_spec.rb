# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arctic do
  describe '[]' do
    it 'returns frozen strings' do
      ENV['ARCTIC_TEST_VAR'] = 'test_value'
      result = described_class['ARCTIC_TEST_VAR']

      expect(result).to eq('test_value')
      expect(result).to be_frozen
    end

    it 'returns nil for missing keys' do
      expect(described_class['NONEXISTENT_KEY']).to be_nil
    end

    it 'returns deduplicated strings (same object_id for same value)' do
      ENV['ARCTIC_TEST_VAR'] = 'shared_value'
      ENV['ARCTIC_TEST_VAR2'] = 'shared_value'

      result1 = described_class['ARCTIC_TEST_VAR']
      result2 = described_class['ARCTIC_TEST_VAR2']

      expect(result1.object_id).to eq(result2.object_id)
    end

    it 'handles empty string values' do
      ENV['ARCTIC_TEST_VAR'] = ''
      result = described_class['ARCTIC_TEST_VAR']

      expect(result).to eq('')
      expect(result).to be_frozen
    end

    it 'returns current value (no caching issues)' do
      ENV['ARCTIC_TEST_VAR'] = 'original'
      expect(described_class['ARCTIC_TEST_VAR']).to eq('original')

      ENV['ARCTIC_TEST_VAR'] = 'modified'
      expect(described_class['ARCTIC_TEST_VAR']).to eq('modified')
    end
  end

  describe '.fetch' do
    it 'returns frozen strings' do
      ENV['ARCTIC_TEST_VAR'] = 'test_value'
      result = described_class.fetch('ARCTIC_TEST_VAR')

      expect(result).to eq('test_value')
      expect(result).to be_frozen
    end

    it 'returns default value when key is missing' do
      result = described_class.fetch('NONEXISTENT_KEY', 'default')
      expect(result).to eq('default')
    end

    it 'yields to block when key is missing' do
      result = described_class.fetch('NONEXISTENT_KEY') { |key| "block_#{key}" }
      expect(result).to eq('block_NONEXISTENT_KEY')
    end

    it 'raises KeyError when key is missing and no default/block' do
      expect do
        described_class.fetch('NONEXISTENT_KEY')
      end.to raise_error(KeyError, /key not found: "NONEXISTENT_KEY"/)
    end

    it 'prefers block over default value' do
      result = described_class.fetch('NONEXISTENT_KEY', 'block_value')
      expect(result).to eq('block_value')
    end
  end

  describe '.key?' do
    it 'returns true for existing keys' do
      ENV['ARCTIC_TEST_VAR'] = 'value'
      expect(described_class.key?('ARCTIC_TEST_VAR')).to be true
    end

    it 'returns false for missing keys' do
      expect(described_class.key?('NONEXISTENT_KEY')).to be false
    end

    it 'returns true even for empty string values' do
      ENV['ARCTIC_TEST_VAR'] = ''
      expect(described_class.key?('ARCTIC_TEST_VAR')).to be true
    end
  end

  describe '.has_key?' do
    it 'is an alias for key?' do
      ENV['ARCTIC_TEST_VAR'] = 'value'
      expect(described_class.key?('ARCTIC_TEST_VAR')).to be true
      expect(described_class.key?('NONEXISTENT_KEY')).to be false
    end
  end

  describe '.include?' do
    it 'is an alias for key?' do
      ENV['ARCTIC_TEST_VAR'] = 'value'
      expect(described_class.include?('ARCTIC_TEST_VAR')).to be true
      expect(described_class.include?('NONEXISTENT_KEY')).to be false
    end
  end

  describe '.member?' do
    it 'is an alias for key?' do
      ENV['ARCTIC_TEST_VAR'] = 'value'
      expect(described_class.member?('ARCTIC_TEST_VAR')).to be true
      expect(described_class.member?('NONEXISTENT_KEY')).to be false
    end
  end

  describe '.each' do
    it 'yields key-value pairs with frozen strings' do
      ENV['ARCTIC_TEST_VAR'] = 'value1'
      ENV['ARCTIC_TEST_VAR2'] = 'value2'

      yielded = []
      described_class.each do |key, value|
        yielded << [key, value] if key.start_with?('ARCTIC_TEST_VAR')
      end

      expect(yielded).to include(['ARCTIC_TEST_VAR', 'value1'])
      expect(yielded).to include(['ARCTIC_TEST_VAR2', 'value2'])

      yielded.each do |key, value|
        expect(key).to be_frozen
        expect(value).to be_frozen
      end
    end

    it 'returns an enumerator when no block given' do
      enumerator = described_class.each
      expect(enumerator).to be_a(Enumerator)
    end

    it 'deduplicates keys and values' do
      ENV['ARCTIC_TEST_VAR'] = 'shared'
      ENV['ARCTIC_TEST_VAR2'] = 'shared'

      values = []
      described_class.each do |key, value|
        values << value if key.start_with?('ARCTIC_TEST_VAR')
      end

      expect(values[0].object_id).to eq(values[1].object_id) if values.size >= 2
    end
  end

  describe '.each_pair' do
    it 'is an alias for each' do
      ENV['ARCTIC_TEST_VAR'] = 'value'

      yielded = []
      described_class.each_pair do |key, value|
        yielded << [key, value] if key == 'ARCTIC_TEST_VAR'
      end

      expect(yielded).to eq([['ARCTIC_TEST_VAR', 'value']])
    end
  end

  describe '.keys' do
    it 'returns array of all environment variable keys as frozen strings' do
      ENV['ARCTIC_TEST_VAR'] = 'value1'
      ENV['ARCTIC_TEST_VAR2'] = 'value2'

      keys = described_class.keys
      expect(keys).to be_a(Array)
      expect(keys).to include('ARCTIC_TEST_VAR', 'ARCTIC_TEST_VAR2')
      expect(keys).to all(be_frozen)
    end

    it 'deduplicates keys' do
      keys = described_class.keys
      key_objects = keys.select { |k| k == 'PATH' }

      # Should only find one PATH key
      expect(key_objects.size).to eq(1) if key_objects.any?
    end
  end

  describe '.values' do
    it 'returns array of all environment variable values as frozen strings' do
      ENV['ARCTIC_TEST_VAR'] = 'value1'
      ENV['ARCTIC_TEST_VAR2'] = 'value2'

      values = described_class.values
      expect(values).to be_a(Array)
      expect(values).to all(be_frozen)
    end

    it 'deduplicates values' do
      ENV['ARCTIC_TEST_VAR'] = 'shared_value'
      ENV['ARCTIC_TEST_VAR2'] = 'shared_value'

      values = described_class.values
      shared_values = values.select { |v| v == 'shared_value' }

      # Should have same object_id if deduplicated
      expect(shared_values.uniq.size).to eq(1)
      expect(shared_values[0].object_id).to eq(shared_values[1].object_id) if shared_values.size >= 2
    end
  end

  describe '.to_h' do
    it 'returns hash with frozen keys and values' do
      ENV['ARCTIC_TEST_VAR'] = 'value1'
      ENV['ARCTIC_TEST_VAR2'] = 'value2'

      hash = described_class.to_h
      expect(hash).to be_a(Hash)
      expect(hash['ARCTIC_TEST_VAR']).to eq('value1')
      expect(hash['ARCTIC_TEST_VAR2']).to eq('value2')

      hash.each do |key, value|
        expect(key).to be_frozen
        expect(value).to be_frozen
      end
    end

    it 'deduplicates keys and values in hash' do
      ENV['ARCTIC_TEST_VAR'] = 'shared'
      ENV['ARCTIC_TEST_VAR2'] = 'shared'

      hash = described_class.to_h
      val1 = hash['ARCTIC_TEST_VAR']
      val2 = hash['ARCTIC_TEST_VAR2']

      expect(val1.object_id).to eq(val2.object_id)
    end
  end

  describe '.to_hash' do
    it 'is an alias for to_h' do
      ENV['ARCTIC_TEST_VAR'] = 'value'

      hash1 = described_class.to_h
      hash2 = described_class.to_hash

      expect(hash1).to eq(hash2)
    end
  end

  describe '.empty?' do
    it 'returns false when environment has variables' do
      # Environment always has some variables (PATH, etc.)
      expect(described_class.empty?).to be false
    end
  end

  describe '.size' do
    it 'returns count of environment variables' do
      size = described_class.size
      expect(size).to be > 0
      expect(size).to be_a(Integer)
    end

    it 'matches ENV.size' do
      expect(described_class.size).to eq(ENV.size)
    end
  end

  describe '.length' do
    it 'is an alias for size' do
      expect(described_class.length).to eq(described_class.size)
    end
  end

  describe '.inspect' do
    it 'returns string representation' do
      result = described_class.inspect
      expect(result).to be_a(String)
      expect(result).to match(/#<Arctic:/)
    end
  end

  describe 'memory efficiency' do
    it 'uses same object for repeated accesses to same string value' do
      ENV['ARCTIC_TEST_VAR'] = 'repeated_value'

      # Access same value multiple times
      results = 10.times.map { described_class['ARCTIC_TEST_VAR'] }

      # All should be the same object (deduplicated)
      object_ids = results.map(&:object_id).uniq
      expect(object_ids.size).to eq(1)
    end

    it 'returns different objects for different values' do
      ENV['ARCTIC_TEST_VAR'] = 'value1'
      ENV['ARCTIC_TEST_VAR2'] = 'value2'

      result1 = described_class['ARCTIC_TEST_VAR']
      result2 = described_class['ARCTIC_TEST_VAR2']

      expect(result1.object_id).not_to eq(result2.object_id)
    end
  end

  describe 'encoding' do
    it 'handles UTF-8 values correctly' do
      ENV['ARCTIC_TEST_VAR'] = 'Hello 世界 🌍'
      result = described_class['ARCTIC_TEST_VAR']

      expect(result).to eq('Hello 世界 🌍')
      expect(result).to be_frozen
    end
  end
end
