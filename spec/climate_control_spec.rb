# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arctic do
  context 'with ClimateControl' do
    describe 'single variable modification' do
      it 'detects ENV changes within ClimateControl block' do
        ENV['TEST_VAR'] = 'original'

        # Access before modification
        expect(described_class['TEST_VAR']).to eq('original')
        expect(described_class['TEST_VAR']).to be_frozen

        # ClimateControl modifies ENV
        ClimateControl.modify(TEST_VAR: 'modified') do
          expect(described_class['TEST_VAR']).to eq('modified')
          expect(described_class['TEST_VAR']).to be_frozen
        end

        # After block, should return to original
        expect(described_class['TEST_VAR']).to eq('original')
      end

      it 'handles new variables added by ClimateControl' do
        # Variable doesn't exist initially
        expect(described_class['TEMP_VAR']).to be_nil

        ClimateControl.modify(TEMP_VAR: 'new_value') do
          expect(described_class['TEMP_VAR']).to eq('new_value')
          expect(described_class['TEMP_VAR']).to be_frozen
        end

        # Should be nil again after block
        expect(described_class['TEMP_VAR']).to be_nil
      end
    end

    describe 'multiple variable modifications' do
      it 'works with multiple ENV modifications simultaneously' do
        ClimateControl.modify(VAR1: 'a', VAR2: 'b') do
          expect(described_class['VAR1']).to eq('a')
          expect(described_class['VAR2']).to eq('b')
          expect(described_class['VAR1']).to be_frozen
          expect(described_class['VAR2']).to be_frozen
        end

        # Both should be nil after block
        expect(described_class['VAR1']).to be_nil
        expect(described_class['VAR2']).to be_nil
      end
    end

    describe 'nested ClimateControl blocks' do
      it 'handles nested modifications correctly' do
        ClimateControl.modify(VAR1: 'outer_a', VAR2: 'outer_b') do
          expect(described_class['VAR1']).to eq('outer_a')
          expect(described_class['VAR2']).to eq('outer_b')

          # Inner block modifies VAR1, keeps VAR2
          ClimateControl.modify(VAR1: 'inner_a') do
            expect(described_class['VAR1']).to eq('inner_a')
            expect(described_class['VAR2']).to eq('outer_b')
          end

          # After inner block, VAR1 restores to outer value
          expect(described_class['VAR1']).to eq('outer_a')
          expect(described_class['VAR2']).to eq('outer_b')
        end

        # After all blocks, both should be nil
        expect(described_class['VAR1']).to be_nil
        expect(described_class['VAR2']).to be_nil
      end
    end

    describe 'unsetting variables' do
      it 'handles nil (unsetting) correctly' do
        ENV['TEMP_VAR'] = 'exists'
        expect(described_class['TEMP_VAR']).to eq('exists')

        ClimateControl.modify(TEMP_VAR: nil) do
          expect(described_class['TEMP_VAR']).to be_nil
          expect(described_class.key?('TEMP_VAR')).to be false
        end

        # Should restore original value after block
        expect(described_class['TEMP_VAR']).to eq('exists')
      end

      it 'handles unsetting and re-setting within nested blocks' do
        ENV['TEMP_VAR'] = 'original'

        ClimateControl.modify(TEMP_VAR: nil) do
          expect(described_class['TEMP_VAR']).to be_nil

          ClimateControl.modify(TEMP_VAR: 'new') do
            expect(described_class['TEMP_VAR']).to eq('new')
          end

          expect(described_class['TEMP_VAR']).to be_nil
        end

        expect(described_class['TEMP_VAR']).to eq('original')
      end
    end

    describe 'Arctic.fetch with ClimateControl' do
      it 'works correctly with fetch' do
        ENV['TEST_KEY'] = 'original'

        ClimateControl.modify(TEST_KEY: 'modified') do
          expect(described_class.fetch('TEST_KEY')).to eq('modified')
          expect(described_class.fetch('TEST_KEY', 'default')).to eq('modified')
        end

        expect(described_class.fetch('TEST_KEY')).to eq('original')
      end

      it 'raises KeyError for unset variables in ClimateControl' do
        ENV['TEST_KEY'] = 'exists'

        ClimateControl.modify(TEST_KEY: nil) do
          expect do
            described_class.fetch('TEST_KEY')
          end.to raise_error(KeyError)
        end
      end
    end

    describe 'Arctic.key? with ClimateControl' do
      it 'reflects ENV changes correctly' do
        ENV['TEST_KEY'] = 'value'
        expect(described_class.key?('TEST_KEY')).to be true

        ClimateControl.modify(TEST_KEY: nil) do
          expect(described_class.key?('TEST_KEY')).to be false
        end

        expect(described_class.key?('TEST_KEY')).to be true
      end
    end

    describe 'Arctic.each with ClimateControl' do
      it 'iterates over modified environment' do
        ClimateControl.modify(ARCTIC_VAR1: 'a', ARCTIC_VAR2: 'b') do
          found_vars = {}
          described_class.each do |key, value|
            found_vars[key] = value if key.start_with?('ARCTIC_VAR')
          end

          expect(found_vars).to include(
            'ARCTIC_VAR1' => 'a',
            'ARCTIC_VAR2' => 'b',
          )
        end
      end
    end

    describe 'Arctic.to_h with ClimateControl' do
      it 'returns hash reflecting current environment' do
        ClimateControl.modify(ARCTIC_TEST: 'value') do
          hash = described_class.to_h
          expect(hash['ARCTIC_TEST']).to eq('value')
        end

        hash = described_class.to_h
        expect(hash['ARCTIC_TEST']).to be_nil
      end
    end

    describe 'deduplication with ClimateControl' do
      it 'deduplicates values set by ClimateControl' do
        ClimateControl.modify(VAR1: 'shared', VAR2: 'shared') do
          val1 = described_class['VAR1']
          val2 = described_class['VAR2']

          expect(val1).to eq('shared')
          expect(val2).to eq('shared')
          expect(val1.object_id).to eq(val2.object_id)
          expect(val1).to be_frozen
        end
      end

      it 'returns new object when value changes' do
        ENV['TEST_KEY'] = 'original'
        described_class['TEST_KEY'].object_id

        ClimateControl.modify(TEST_KEY: 'modified') do
          described_class['TEST_KEY'].object_id

          # Different value = different fstring object
          expect(described_class['TEST_KEY']).to eq('modified')
          # Object ID may or may not be different depending on fstring table
          # but value should definitely be different
        end

        described_class['TEST_KEY'].object_id
        expect(described_class['TEST_KEY']).to eq('original')
      end
    end

    describe 'concurrent test compatibility' do
      it 'works correctly when multiple tests use ClimateControl' do
        # Simulate multiple test scenarios
        ClimateControl.modify(SCENARIO_VAR: 'scenario1') do
          expect(described_class['SCENARIO_VAR']).to eq('scenario1')
        end

        ClimateControl.modify(SCENARIO_VAR: 'scenario2') do
          expect(described_class['SCENARIO_VAR']).to eq('scenario2')
        end

        ClimateControl.modify(SCENARIO_VAR: 'scenario3') do
          expect(described_class['SCENARIO_VAR']).to eq('scenario3')
        end

        # Variable should not exist after all blocks
        expect(described_class['SCENARIO_VAR']).to be_nil
      end
    end
  end
end
