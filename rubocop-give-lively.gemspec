# frozen_string_literal: true

require_relative 'lib/rubocop/give/lively/version'

NON_GEM_FILES = ['Gemfile', 'Gemfile.lock', 'Guardfile', 'bin/lint'].freeze

Gem::Specification.new do |spec|
  spec.name = 'rubocop-give-lively'
  spec.version = Rubocop::Give::Lively::VERSION
  spec.authors = ['Give Lively']

  spec.summary = "A shareable configuration of Give Lively's rubocop rules."
  spec.homepage = 'https://github.com/givelively/rubocop-give-lively'
  spec.license = 'MIT'
  spec.required_ruby_version = '3.1.6'

  spec.extra_rdoc_files = ['README.md']

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rubocop'
  spec.add_dependency 'rubocop-performance'
  spec.add_dependency 'rubocop-rake'
  spec.add_dependency 'rubocop-rspec'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
