# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake/extensiontask'

# Define the extension task
Rake::ExtensionTask.new('arctic') do |ext|
  ext.lib_dir = 'lib/arctic'
end

RSpec::Core::RakeTask.new(:spec)

# Ensure extension is compiled before running specs
task spec: :compile

task default: :spec
