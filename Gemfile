source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "4.0.9"

gemspec

gem "easy_style", git: "git@gitlab.dd-life.com:corp.front_end/easy_style_engine.git", branch: "main"
gem "rails", ">= 8.1.4.1"

gem "debug"
gem "rubocop"
gem "rubocop-capybara", require: false
gem "rubocop-erb"
gem "rubocop-minitest"
gem "rubocop-rails-omakase"
gem "rubocop-rake"

gem "guard"
gem "guard-bundler"
gem "guard-minitest"
gem "guard-rubocop"
gem "minitest"
gem "minitest-reporters"
gem "mocha"
gem "pg"
gem "propshaft"
gem "puma"

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"
end
