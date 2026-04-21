# frozen_string_literal: true

require_relative "lib/cfc/version"

Gem::Specification.new do |spec|
  spec.name = "cfc"
  spec.version = Cfc::VERSION
  spec.authors = ["Steffen Roller"]
  spec.email = ["steffen.roller@gmail.com"]

  spec.summary = "CFC rating data manager for Chess Canada"
  spec.description = "A Ruby gem to download, store, and compare Chess Canada (CFC) player ratings"
  spec.homepage = "https://github.com/sroller/cfc"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sroller/cfc"
  spec.metadata["changelog_uri"] = "https://github.com/sroller/cfc/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "csv", "~> 1.0"
  spec.add_dependency "mail", "~> 2.8"
  spec.add_dependency "sqlite3", "~> 2.0"
  spec.add_dependency "thor", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
