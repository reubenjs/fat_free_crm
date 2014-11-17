# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'fat_free_crm/version'

Gem::Specification.new do |gem|
  gem.name = 'fat_free_crm'
  gem.authors = ['Michael Dvorkin', 'Ben Tillman', 'Nathan Broadbent', 'Stephen Kenworthy']
  gem.summary = 'Fat Free CRM'
  gem.description = 'An open source, Ruby on Rails customer relationship management platform'
  gem.homepage = 'http://fatfreecrm.com'
  gem.email = ['mike@fatfreecrm.com', 'nathan@fatfreecrm.com', 'warp@fatfreecrm.com', 'steveyken@gmail.com']
  gem.files = `git ls-files`.split("\n")
  gem.version = FatFreeCRM::VERSION::STRING
  gem.required_ruby_version = '>= 1.9'
  gem.license = 'MIT'

  gem.add_dependency 'rails',               '~> 3.2.12'
  gem.add_dependency 'jquery-rails',        '~> 2.1.4' # pegs us to jQuery 1.8
  gem.add_dependency 'select2-rails'
  gem.add_dependency 'simple_form',         '~> 2.0.1'
  gem.add_dependency 'will_paginate'
  gem.add_dependency 'paperclip'
  # Manually added paperclip gem dependency "cocaine" in order to fix load error: "no such file to load -- cocaine"
  gem.add_dependency 'cocaine'
  gem.add_dependency 'paper_trail',         '~> 2.7.0' # not ready for v3 yet
  gem.add_dependency 'authlogic',           '3.1.0'
  gem.add_dependency 'acts_as_commentable', '~> 3.0.1'
  gem.add_dependency 'acts-as-taggable-on', '~> 2.3.3'
  gem.add_dependency 'dynamic_form'
  gem.add_dependency 'haml',                '~> 3'
  gem.add_dependency 'sass',                '~> 3'
  gem.add_dependency 'acts_as_list',        '~> 0.1.4'
  gem.add_dependency 'ffaker',              '>= 1.12.0'
  gem.add_dependency 'cancan'
  gem.add_dependency 'font-awesome-rails'
  gem.add_dependency 'premailer'
  gem.add_dependency 'nokogiri'
  gem.add_dependency 'responds_to_parent',  '>= 1.1.0'
  gem.add_dependency 'rails3-jquery-autocomplete'
  gem.add_dependency 'valium'
  gem.add_dependency 'psych', '~> 1'        if RUBY_VERSION.to_f < 2.0
  gem.add_dependency "combined_time_select", "~> 0.0.1"
  gem.add_dependency 'mandrill-rails'
  gem.add_dependency 'mailchimp'
  gem.add_dependency 'delayed_job'
  gem.add_dependency 'delayed_job_active_record'
  gem.add_dependency 'ice_cube'
  gem.add_dependency 'cache_digests'
  gem.add_dependency 'whenever'
  gem.add_dependency 'daemons'
  gem.add_dependency 'dalli'
  gem.add_dependency 'chronic'
  gem.add_dependency 'tinymce-rails', '~> 4.1.6'

  # FatFreeCRM has released it's own versions of the following gems:
  #-----------------------------------------------------------------
  gem.add_dependency 'ransack_ui',          '>= 1.1.0'
  gem.add_dependency 'email_reply_parser_ffcrm'
end
