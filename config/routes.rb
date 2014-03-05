# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
Rails.application.routes.draw do
  resources :lists

  root :to => 'home#index'

  match 'activities' => 'home#index'
  match 'admin'      => 'admin/users#index',       :as => :admin
  match 'login'      => 'authentications#new',     :as => :login
  match 'logout'     => 'authentications#destroy', :as => :logout
  match 'profile'    => 'users#show',              :as => :profile
  match 'signup'     => 'users#new',               :as => :signup

  match '/home/options',  :as => :options
  match '/home/toggle',   :as => :toggle
  match '/home/timeline', :as => :timeline
  match '/home/timezone', :as => :timezone
  match '/home/redraw',   :as => :redraw

  resource  :authentication, :except => [:index, :edit]
  resources :comments,       :except => [:new, :show]
  resources :emails,         :only   => [:destroy]
  resources :passwords,      :only   => [:new, :create, :edit, :update]

  resources :accounts, :id => /\d+/ do
    collection do
      get  :advanced_search
      post :filter
      get  :options
      get  :field_group
      match :auto_complete
      get  :redraw
      get  :versions
    end
    member do
      get :cold_contacts
      get :redraw_show
      post :move_contact
      put  :attach
      post :discard
      post :subscribe
      post :unsubscribe
      get  :contacts
      get  :opportunities
      get :archive
      get :activate
    end
  end

  resources :campaigns, :id => /\d+/ do
    collection do
      get  :advanced_search
      post :filter
      get  :options
      get  :field_group
      match :auto_complete
      get  :redraw
      get  :versions
    end
    member do
      put  :attach
      post :discard
      post :subscribe
      post :unsubscribe
      get  :leads
      get  :opportunities
    end
  end

  resources :contacts, :id => /\d+/ do
    collection do
      get  :advanced_search
      post :filter
      get  :options
      get  :field_group
      match :auto_complete
      get  :redraw
      get  :versions
      get :attendances
      get :mailchimp_webhooks
      post :mailchimp_webhooks
      get :mandrill_webhooks
      post :mandrill_webhooks
      post :bsg_webhooks
    end
    member do
      post :move_contact
      put  :attach
      post :discard
      post :subscribe
      post :unsubscribe
      get :opportunities
      get :contact_groups
      get :mailing_lists
      get :tags
      get :confirm
      get :archive
      get :activate
      post :graduate
    end
  end

  resources :leads, :id => /\d+/ do
    collection do
      get  :advanced_search
      post :filter
      get  :options
      get  :field_group
      match :auto_complete
      get  :redraw
      get  :versions
      get  :autocomplete_account_name
    end
    member do
      get  :convert
      post :discard
      post :subscribe
      post :unsubscribe
      put  :attach
      put  :promote
      put  :reject
    end
  end

  resources :opportunities, :id => /\d+/ do
    collection do
      get  :advanced_search
      post :filter
      get  :options
      get  :field_group
      match :auto_complete
      get  :redraw
      get  :versions
    end
    member do
      put  :attach
      post :discard
      post :subscribe
      post :unsubscribe
      get  :contacts
    end
  end

  resources :tasks, :id => /\d+/ do
    collection do
      post :filter
      match :auto_complete
    end
    member do
      put  :complete
    end
  end

  resources :users, :id => /\d+/, :except => [:index, :destroy] do
    member do
      get  :avatar
      get  :password
      put  :upload_avatar
      put  :change_password
      get  :redraw
      post :move_contact
    end
    collection do
      get  :opportunities_overview
      match :auto_complete
    end
  end
  
  resources :contact_groups, :id => /\d+/ do
    collection do
      get  :advanced_search
      post :filter
      get  :options
      get  :field_group
      match :auto_complete
      get  :redraw
      get  :versions
      get :email
    end
    member do
      get :redraw_show
      get :archive
      get :activate
      put  :attach
      post :discard
      post :subscribe
      post :unsubscribe
      get :contacts
      get :opportunities
      get :mandrill
      post :mandrill_send
    end
  end
  
  resources :mandrill_emails, :id => /\d+/ do
    collection do
      get  :advanced_search
      post :filter
      get  :options
      get  :field_group
      match :auto_complete
      get  :redraw
      get  :versions
      get :compose
    end
    member do
      put :save
      put  :attach
      post :discard
      post :subscribe
      post :unsubscribe
      post :mandrill_send
    end
  end
  
  resources :events, :id => /\d+/ do
    collection do
      get  :advanced_search
      post :filter
      get  :options
      get  :field_group
      match :auto_complete
      get  :redraw
      get  :versions
      get :toggle_comments
    end
    member do
      get :reports
      get :email_registrants
      put :send_emails
      get :generate_report
      get :redraw_show
      get :archive
      get :activate
      put  :attach
      #put :mark
      #put :unmark
      post :discard
      post :subscribe
      post :unsubscribe
      get :event_instances
    end
  end
  
  resources :event_instances, :id => /\d+/ do
    collection do
      get  :redraw
      get  :versions
    end
    member do
      put  :attach
      post :mark
      post :unmark
      post :discard
      post :subscribe
      post :unsubscribe
      get :report_attendance
    end
  end
  
  resources :registrations, :id => /\d+/ do
    collection do
      #post :redraw
      get :versions
    end
    member do
      put  :attach
      post :discard
      post :subscribe
      post :unsubscribe
    end
  end
  
  namespace :admin do
    resources :groups
    
    resources :imports do
      collection do
        post :import
        post :import_supporters
      end
    end
    
    resources :users do
      collection do
        match :auto_complete
      end
      member do
        get :confirm
        put :suspend
        put :reactivate
      end
    end

    resources :field_groups, :except => [:index, :show] do
      collection do
        post :sort
      end
      member do
        get :confirm
      end
    end

    resources :fields do
      collection do
        match :auto_complete
        get   :options
        get   :redraw
        post  :sort
        get   :subform
      end
    end

    resources :tags, :except => [:show] do
      member do
        get :confirm
      end
    end

    resources :fields, :as => :custom_fields
    resources :fields, :as => :core_fields

    resources :settings, :only => :index
    resources :plugins,  :only => :index
  end

end
