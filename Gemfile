source 'https://rubygems.org'

# Uncomment the database that you have configured in config/database.yml
# ----------------------------------------------------------------------
 gem 'mysql2'
# gem 'sqlite3'
#gem 'pg', '~> 0.13.2'

# Removes a gem dependency
def remove(name)
  @dependencies.reject! {|d| d.name == name }
end

# Replaces an existing gem dependency (e.g. from gemspec) with an alternate source.
def gem(name, *args)
  remove(name)
  super
end

# Bundler no longer treats runtime dependencies as base dependencies.
# The following code restores this behaviour.
# (See https://github.com/carlhuda/bundler/issues/1041)
spec = Bundler.load_gemspec( File.expand_path("../fat_free_crm.gemspec", __FILE__) )
spec.runtime_dependencies.each do |dep|
  gem dep.name, *(dep.requirement.as_list)
end

# Remove premailer auto-require
gem 'premailer', :require => false

# Remove fat_free_crm dependency, to stop it from being auto-required too early.
remove 'fat_free_crm'
#remove 'ffcrm_merge'

group :development do
  # don't load these gems in travis
  unless ENV["CI"]
    gem 'thin'
    gem 'quiet_assets'
    gem 'rvm-capistrano'
    gem 'capistrano_colors'
    gem 'guard'
    gem 'guard-rspec'
    gem 'guard-rails'
    gem 'rb-inotify', :require => false
    gem 'rb-fsevent', :require => false
    gem 'rb-fchange', :require => false
  end
end

group :development, :test do
  gem 'rspec-rails'
  gem 'headless'
  gem 'byebug' unless ENV["CI"]
  gem 'pry-rails' unless ENV["CI"]
  gem 'pry-nav' unless ENV["CI"]
  gem 'pry-stack_explorer' unless ENV["CI"]
  gem 'awesome_print' unless ENV["CI"]
end

group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'database_cleaner'
  gem "acts_as_fu"
  gem 'factory_girl_rails'
  gem 'zeus' unless ENV["CI"]
  gem 'coveralls', :require => false
end

group :heroku do
  gem 'unicorn', :platform => :ruby
  gem 'rails_12factor'
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier',     '>= 1.0.3'
  gem 'execjs'
  gem 'therubyracer', :platform => :ruby unless ENV["CI"]
end

gem 'turbo-sprockets-rails3'
#gem 'ffcrm_merge', :path => "/Users/reuben/Development/Rails/ffcrm_merge"
gem 'ffcrm_merge', :git => "git://github.com/reubenjs/ffcrm_merge.git"
gem 'saasu', :git => 'git://github.com/reubenjs/saasu.git' 
#gem 'saasu', :path => "/Users/reuben/Development/Rails/saasu" 
gem 'secret_token_replacer', :git => 'git://github.com/digineo/secret_token_replacer.git'
