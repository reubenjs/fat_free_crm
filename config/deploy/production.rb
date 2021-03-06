# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
#$:.unshift File.expand_path('./lib', ENV['rvm_path'])

require 'rvm/capistrano'
require 'bundler/capistrano'
require 'whenever/capistrano'
require 'delayed/recipes'
require 'secret_token_replacer/recipes'
load    'deploy/assets'

set :application,     'esCRM'
set :repository,      'git://github.com/reubenjs/fat_free_crm.git'
set :branch,          'master'
set :scm,             :git
set :deploy_to,       "/var/www/#{application}"
set :user,            'deploy'
set :use_sudo,        false
set :rvm_type,        :system
set :rvm_ruby_string, '2.1'
set :whenever_command, "bundle exec whenever"
set :rails_env, "production" #added for delayed job 
server                '192.168.5.223', :app, :web, :db, primary: true

# Use local key instead of key installed on the server.
# If not working run "ssh-add ~/.ssh/id_rsa" on your local machine.
ssh_options[:forward_agent] = true

namespace :deploy do
  task :start, roles: :app do
    run "touch #{current_release}/tmp/restart.txt"
  end
  
  task :stop, roles: :app do
    # Do nothing.
  end
  
  desc 'Tell Passenger to restart the app.'
  task :restart, roles: :app, except: { no_release: true } do
    run "touch #{current_release}/tmp/restart.txt"
    #run "cd #{current_release} && passenger stop -p 3001"
    #run "cd #{current_release} && passenger start -a 127.0.0.1 -p 3001 -d -e production"
  end
  
  desc 'Symlink shared configs and folders on each release.'
  task :symlink_shared do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/config/settings.yml #{release_path}/config/settings.yml"
    run "rm -rf #{release_path}/vendor/ruby"
    run "ln -nfs #{shared_path}/bundle/ruby #{release_path}/vendor/ruby"
  end
end

after "deploy:stop",    "delayed_job:stop"
after "deploy:start",   "delayed_job:start"
after "deploy:restart", "delayed_job:restart"
after 'deploy:finalize_update', 'deploy:symlink_shared'
