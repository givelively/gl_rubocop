# frozen_string_literal: true

require_relative 'lib/gl_rubocop/version'

Gem::Specification.new do |spec|
  spec.name = 'gl_rubocop'
  spec.version = GLRubocop::VERSION
  spec.authors = ['Give Lively']

  spec.summary = "A shareable configuration of Give Lively's rubocop rules."
  spec.homepage = 'https://github.com/givelively/gl_rubocop'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.extra_rdoc_files = ['README.md']

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = %w[gl_rubocop.gemspec README.md LICENSE default.yml] +
               `git ls-files | grep -E '^(lib)'`.split("\n")

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rubocop', '~> 1.90'
  spec.add_dependency 'rubocop-capybara', '>= 2.22'
  spec.add_dependency 'rubocop-erb', '>= 0.6'
  spec.add_dependency 'rubocop-haml', '>= 0.3'
  spec.add_dependency 'rubocop-i18n', '>= 3.2'
  spec.add_dependency 'rubocop-magic_numbers'
  spec.add_dependency 'rubocop-performance', '>= 1.24'
  spec.add_dependency 'rubocop-rails', '>= 2.30'
  spec.add_dependency 'rubocop-rake', '>= 0.7'
  spec.add_dependency 'rubocop-rspec', '~> 3.5'
  spec.add_dependency 'rubocop-rspec_rails', '>= 2.31'
  spec.add_dependency 'rubocop-sorbet', '>= 0.9'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
