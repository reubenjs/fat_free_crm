set :stages, %w(production) #add other stages here
set :default_stage, "production"
require 'capistrano/ext/multistage'

set :application, "esCRM"
set :user, "deploy"
set :group, "deploy"

set :scm, :git
set :repository,      'git://github.com/reubenjs/fat_free_crm.git'
set :branch,          'master'

set :deploy_to, "/var/www/#{application}"
set :rails_env, 'production'