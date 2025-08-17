source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.2'

gem 'rails', '~> 8.0.0'
gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'
gem 'bootsnap', '>= 1.4.4', require: false
gem 'rack-cors'

# Background Jobs
gem 'solid_queue'

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'minitest-rails'
  gem 'factory_bot_rails'
  gem 'database_cleaner-active_record'
  gem 'faker'
  gem 'mocha'
end

group :development do
  gem 'listen', '~> 3.3'
  gem 'spring'
end