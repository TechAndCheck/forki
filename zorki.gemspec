# frozen_string_literal: true

require_relative "lib/zorki/version"

Gem::Specification.new do |spec|
  spec.name          = "zorki"
  spec.version       = Zorki::VERSION
  spec.authors       = ["Christopher Guess"]
  spec.email         = ["cguess@gmail.com"]

  spec.summary       = "A gem to scrape Instagram pages for archive purposes."
  # spec.description   = "TODO: Write a longer description or delete this line."
  # spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "capybara" # For scraping and running browsers
  spec.add_dependency "apparition" # A Chrome driver for Capybara
  spec.add_dependency "typhoeus" # For making API requests
  spec.add_dependency "oj" # A faster JSON parser/loader than stdlib
  spec.add_dependency "selenium-webdriver" # Webdriver selenium

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
