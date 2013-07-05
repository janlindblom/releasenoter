# coding: utf-8

require File.expand_path('../lib/releasenoter/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "releasenoter"
  gem.version       = Releasenoter::VERSION
  gem.platform      = Gem::Platform::RUBY
  gem.summary       = "Releasenoter generates releasenotes from Git logs."
  gem.description   = "Releasenoter generates releasenotes from Git logs."
  gem.license       = "MIT"
  gem.authors       = ["Jan Lindblom"]
  gem.email         = "jan.lindblom@mittmedia.se"
  gem.homepage      = "https://github.com/janlindblom/releasenoter#readme"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rdoc'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rubygems-tasks'
  gem.add_dependency "git"
  gem.add_dependency "trollop"
  gem.add_dependency "formatador"
  gem.add_dependency "bundler"
  gem.add_dependency "rake"
end
