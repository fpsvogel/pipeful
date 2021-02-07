require_relative "lib/pipeful/version"

Gem::Specification.new do |spec|
  spec.name          = "pipeful"
  spec.version       = Pipeful::VERSION
  spec.authors       = ["Felipe Vogel"]
  spec.email         = ["fps.vogel@gmail.com"]

  spec.summary       = "Pipeful is a simple DSL for piping data through callable objects."
  spec.homepage      = "https://github.com/fpsvogel/pipeful"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.add_development_dependency "binding_of_caller", "~> 0.8"
  spec.add_development_dependency "minitest", "~> 5.13"
  spec.add_development_dependency "minitest-reporters", "~> 1.4"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fpsvogel/pipeful"
  spec.metadata["changelog_uri"] = "https://github.com/fpsvogel/pipeful/blob/master/CHANGELOG.md"

  spec.files = ["lib/pipeful.rb", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]
end
