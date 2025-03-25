# frozen_string_literal: true

source 'https://rubygems.org'

# Include runtime dependencies from gemspec
gemspec

group :development, :test do
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'grape'
  gem 'httparty'
  gem 'rack-test'
  gem 'rspec', '~> 3.13'
  gem 'rubyzip', '~> 2.3'
  gem 'webmock'
end

group :development do
  gem 'rack-mini-profiler', '~> 2.0'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'spring'
  gem 'web-console', '>= 4.2.0'
end
