# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'arctic'
  spec.version = File.read(File.join(__dir__, 'lib/arctic.rb'))[/VERSION\s*=\s*(['"])([0-9a-z\.-]*)\1/, 2]
  spec.authors = ['Persona']
  spec.email = ['rubygems@withpersona.com']

  spec.summary = 'Frozen, deduplicated environment variable access'
  spec.description = 'Arctic provides an ENV-like interface that returns frozen, ' \
                     'deduplicated strings to reduce memory allocations. ' \
                     "Implemented as a C extension using Ruby's fstring table."
  spec.homepage = 'https://github.com/persona-id/arctic'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = IO.popen(%w[git ls-files -z], &:read).split("\x0").select do |f|
    f.match?(%r{\A(?:lib|ext|sig)/}) || f.match?(%r{\A(?:LICENSE\.txt|README\.md|CHANGELOG\.md)\z})
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(/\Aexe\//) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Specify C extension to compile
  spec.extensions = ['ext/arctic/extconf.rb']
end
