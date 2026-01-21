# typed: false
# frozen_string_literal: true

# rubocop:disable Persona/AvoidObjectSpace

require 'spec_helper'

RSpec.describe Arctic do
  describe 'zero allocations after initial intern' do
    it 'allocates no strings on repeated [] access' do
      ENV['ARCTIC_ALLOC_TEST'] = 'shared_value'
      key = 'ARCTIC_ALLOC_TEST' # Freeze key to avoid allocating it

      # Warm up - intern the string first
      first = described_class[key]
      expect(first).to be_frozen

      # Run once more to ensure everything is warmed up
      described_class[key]

      # Now measure - subsequent calls should allocate zero strings
      allocations = measure_string_allocations do
        100.times { described_class[key] }
      end

      expect(allocations).to eq(0)

      ENV.delete('ARCTIC_ALLOC_TEST')
    end

    it 'allocates no strings on repeated fetch access' do
      ENV['ARCTIC_ALLOC_TEST'] = 'test_value'
      key = 'ARCTIC_ALLOC_TEST'

      # Warm up - intern the string
      described_class.fetch(key)
      described_class.fetch(key)

      # Now measure - subsequent calls should allocate zero strings
      allocations = measure_string_allocations do
        100.times { described_class.fetch(key) }
      end

      expect(allocations).to eq(0)

      ENV.delete('ARCTIC_ALLOC_TEST')
    end

    it 'allocates no strings when multiple keys have the same value' do
      ENV['ARCTIC_KEY1'] = 'duplicate_value'
      ENV['ARCTIC_KEY2'] = 'duplicate_value'
      key1 = 'ARCTIC_KEY1'
      key2 = 'ARCTIC_KEY2'

      # Warm up - intern both (should create only one interned string)
      described_class[key1]
      described_class[key2]
      described_class[key1]
      described_class[key2]

      # Now measure - accessing either should not allocate
      allocations = measure_string_allocations do
        50.times do
          described_class[key1]
          described_class[key2]
        end
      end

      expect(allocations).to eq(0)

      ENV.delete('ARCTIC_KEY1')
      ENV.delete('ARCTIC_KEY2')
    end

    it 'allocates no strings on repeated each iterations' do
      ENV['ARCTIC_EACH_TEST1'] = 'value1'
      ENV['ARCTIC_EACH_TEST2'] = 'value2'
      prefix = 'ARCTIC_EACH_'

      # Warm up - intern all keys/values
      2.times { described_class.each { |k, v| [k, v] if k.start_with?(prefix) } }

      # Now measure - subsequent iterations should allocate zero strings
      allocations = measure_string_allocations do
        10.times do
          described_class.each { |k, v| [k, v] if k.start_with?(prefix) }
        end
      end

      expect(allocations).to eq(0)

      ENV.delete('ARCTIC_EACH_TEST1')
      ENV.delete('ARCTIC_EACH_TEST2')
    end

    it 'allocates no strings on repeated keys/values calls' do
      ENV['ARCTIC_KEYS_TEST'] = 'test_value'

      # Warm up - intern all strings
      2.times do
        described_class.keys
        described_class.values
      end

      # Now measure - subsequent calls should allocate zero strings
      # (arrays are new, but strings are interned)
      allocations = measure_string_allocations do
        10.times do
          described_class.keys
          described_class.values
        end
      end

      expect(allocations).to eq(0)

      ENV.delete('ARCTIC_KEYS_TEST')
    end

    it 'allocates no strings on repeated to_h calls' do
      ENV['ARCTIC_HASH_TEST'] = 'hash_value'

      # Warm up - intern all strings
      2.times { described_class.to_h }

      # Now measure - subsequent calls should allocate zero strings
      allocations = measure_string_allocations do
        10.times { described_class.to_h }
      end

      expect(allocations).to eq(0)

      ENV.delete('ARCTIC_HASH_TEST')
    end
  end

  describe 'memory comparison with ENV' do
    it 'uses significantly less memory than ENV for duplicate values' do
      # Setup: create many ENV vars with same value
      100.times do |i|
        ENV["ARCTIC_MEM_TEST_#{i}"] = 'shared_value_for_memory_test'
      end

      # Measure ENV allocations
      env_before = count_string_objects
      env_values = []
      100.times { |i| env_values << ENV.fetch("ARCTIC_MEM_TEST_#{i}", nil) }
      env_after = count_string_objects
      env_allocations = env_after - env_before

      # Clear for Arctic test
      env_values.clear

      # Measure Arctic allocations (first access - will intern)
      arctic_before = count_string_objects
      arctic_values = []
      100.times { |i| arctic_values << described_class["ARCTIC_MEM_TEST_#{i}"] }
      arctic_after = count_string_objects
      arctic_allocations = arctic_after - arctic_before

      # Arctic should allocate far fewer strings (ideally just 1 for the shared value)
      expect(arctic_allocations).to be < (env_allocations / 2)

      # Verify all Arctic values share the same object
      expect(arctic_values.map(&:object_id).uniq.size).to eq(1)

      # Cleanup
      100.times { |i| ENV.delete("ARCTIC_MEM_TEST_#{i}") }
    end

    it 'returns the same object for identical values' do
      ENV['ARCTIC_OBJ_TEST1'] = 'same_value'
      ENV['ARCTIC_OBJ_TEST2'] = 'same_value'

      obj1 = described_class['ARCTIC_OBJ_TEST1']
      obj2 = described_class['ARCTIC_OBJ_TEST2']

      expect(obj1.object_id).to eq(obj2.object_id)
      expect(obj1).to be_frozen
      expect(obj2).to be_frozen

      ENV.delete('ARCTIC_OBJ_TEST1')
      ENV.delete('ARCTIC_OBJ_TEST2')
    end
  end

  describe 'allocation behavior with ClimateControl' do
    it 'allocates minimal strings when values change via ClimateControl' do
      ENV['ARCTIC_CC_ALLOC'] = 'original'
      key = 'ARCTIC_CC_ALLOC'

      # Warm up - intern the original value
      2.times { described_class[key] }

      ClimateControl.modify(ARCTIC_CC_ALLOC: 'modified') do
        # Warm up with new value - will intern "modified"
        2.times { described_class[key] }

        # Now measure - subsequent accesses should not allocate
        allocations = measure_string_allocations do
          10.times { described_class[key] }
        end
        expect(allocations).to eq(0)
      end

      # Back to original - already interned, should not allocate
      allocations = measure_string_allocations do
        10.times { described_class[key] }
      end
      expect(allocations).to eq(0)

      ENV.delete('ARCTIC_CC_ALLOC')
    end
  end

  private

    def count_string_objects
      GC.start
      ObjectSpace.count_objects[:T_STRING]
    end

    # Helper to measure string allocations using ObjectSpace tracing
    def measure_string_allocations
      require 'objspace'

      ObjectSpace.trace_object_allocations_start
      ObjectSpace.trace_object_allocations_clear

      yield

      # Count only NEW string allocations during the block
      new_strings = 0
      ObjectSpace.each_object(String) do |str|
        gen = ObjectSpace.allocation_generation(str)
        new_strings += 1 if gen && gen > 0
      end

      ObjectSpace.trace_object_allocations_stop

      new_strings
    end
end

# Custom RSpec matcher for checking exact allocation count
RSpec::Matchers.define :allocate_strings do |expected_count = 0|
  match do |block|
    GC.start
    GC.disable

    before_count = ObjectSpace.count_objects[:T_STRING]
    block.call
    after_count = ObjectSpace.count_objects[:T_STRING]

    GC.enable

    @allocated = after_count - before_count
    @allocated == expected_count
  end

  failure_message do
    "expected to allocate exactly #{expected} strings, but allocated #{@allocated} strings"
  end

  failure_message_when_negated do
    "expected not to allocate exactly #{expected} strings, but allocated #{@allocated} strings"
  end

  supports_block_expectations
end

# rubocop:enable Persona/AvoidObjectSpace
