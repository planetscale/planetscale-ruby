# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'planetscale/version'

Gem::Specification.new do |spec|
  spec.name          = 'planetscale'
  spec.version       = PlanetScale::VERSION
  spec.authors       = ['Nick Van Wiggeren', 'Mike Coutermarsh', 'David Graham']
  spec.email         = ['nick@planetscale.com']

  spec.summary       = 'Write a short summary, because RubyGems requires one.'
  spec.description   = 'Write a longer description or delete this line.'
  spec.homepage      = 'https://planetscale.com/'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.pkg.github.com/'

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/planetscale/planetscale-ruby'
    spec.metadata['changelog_uri'] = 'https://github.com/planetscale/planetscale-ruby'
    spec.metadata['github_repo'] = 'ssh://github.com/planetscale/planetscale-ruby'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) } + Dir.glob("proxy/*")
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.2'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'minitest'

  spec.add_runtime_dependency 'ffi', '~> 1'
end
