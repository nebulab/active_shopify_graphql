# frozen_string_literal: true

require_relative 'lib/active_shopify_graphql/version'

Gem::Specification.new do |spec|
  spec.name = 'active_shopify_graphql'
  spec.version = ActiveShopifyGraphQL::VERSION
  spec.authors = ['Nicolò Rebughini']
  spec.email = ['nicolorebughini@nebulab.com']

  spec.summary = 'An ActiveRecord-like interface for Shopify GraphQL APIs'
  spec.description = "ActiveShopifyGraphQL provides an ActiveRecord-like interface for interacting with Shopify's GraphQL APIs, supporting both Admin API and Customer Account API with automatic query building and response mapping."
  spec.homepage = 'https://github.com/nebulab/active_shopify_graphql'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/nebulab/active_shopify_graphql'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'activemodel', '>= 7.0'
  spec.add_dependency 'activesupport', '>= 7.0'
  spec.add_dependency 'globalid', '>= 1.3'

  # Development dependencies
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
end
