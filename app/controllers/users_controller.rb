# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class UsersController < ApplicationController

  before_filter :set_current_tab, :only => [ :show, :opportunities_overview ] # Don't hightlight any tabs.

  check_authorization
  load_and_authorize_resource # handles all security

  respond_to :html, :only => [ :show, :new ]

  # GET /users/1
  # GET /users/1.js
  #----------------------------------------------------------------------------
  def show
    @user = current_user if params[:id].nil?
    respond_with(@user)
  end

  # GET /users/new
  # GET /users/new.js
  #----------------------------------------------------------------------------
  def new
    respond_with(@user)
  end

  # POST /users
  # POST /users.js
  #----------------------------------------------------------------------------
  def create
    if @user.save
      if Setting.user_signup == :needs_approval
        flash[:notice] = t(:msg_account_created)
        redirect_to login_url
      else
        flash[:notice] = t(:msg_successful_signup)
        redirect_back_or_default profile_url
      end
    else
      render :new
    end
  end

  # GET /users/1/edit.js
  #----------------------------------------------------------------------------
  def edit
    respond_with(@user)
  end
  
  def move_contact
    @contact = Contact.find(params[:contact_id])
    @contact.assigned_to = params[:id] # confusing, but it's as good as I could figure out with the dropable helper
    @contact.save

    #data for sidebar...
    @folder_total = Hash[
      Account.my.map do |key|
        [ key, key.contacts.count ]
      end
    ]
    
    organized = @folder_total.values.sum
    @folder_total[:other] = Contact.includes(:account).where("accounts.id IS NULL").count
    @folder_total[:all] = @folder_total[:other] + organized
    
    # Assigned to each user
    @user_total = Hash[
      User.all.map do |key|
        [ key, Contact.where('assigned_to = ?', key).count ]
      end
    ]
    organized = @user_total.values.sum
    @user_total[:other] = Contact.where("assigned_to IS NULL").count
    @user_total[:all] = organized + @user_total[:other]
  end

  # PUT /users/1
  # PUT /users/1.js
  #----------------------------------------------------------------------------
  def update
    @user.update_attributes(params[:user])
    respond_with(@user)
  end

  # GET /users/1/avatar
  # GET /users/1/avatar.js
  #----------------------------------------------------------------------------
  def avatar
    respond_with(@user)
  end

  # PUT /users/1/upload_avatar
  # PUT /users/1/upload_avatar.js
  #----------------------------------------------------------------------------
  def upload_avatar
    if params[:gravatar]
      @user.avatar = nil
      @user.save
      render
    else
      if params[:avatar]
        @user.avatar = Avatar.new(params[:avatar].merge(:entity => @user))
        unless @user.save && @user.avatar.errors.blank?
          @user.avatar.errors.clear
          @user.avatar.errors.add(:image, t(:msg_bad_image_file))
        end
      end
      responds_to_parent do
        # Without return RSpec2 screams bloody murder about rendering twice:
        # within the block and after yield in responds_to_parent.
        render and (return if Rails.env.test?)
      end
    end
  end

  # GET /users/1/password
  # GET /users/1/password.js
  #----------------------------------------------------------------------------
  def password
    respond_with(@user)
  end

  # PUT /users/1/change_password
  # PUT /users/1/change_password.js
  #----------------------------------------------------------------------------
  def change_password
    if @user.valid_password?(params[:current_password], true) || @user.password_hash.blank?
      unless params[:user][:password].blank?
        @user.password = params[:user][:password]
        @user.password_confirmation = params[:user][:password_confirmation]
        @user.save
        flash[:notice] = t(:msg_password_changed)
      else
        flash[:notice] = t(:msg_password_not_changed)
      end
    else
      @user.errors.add(:current_password, t(:msg_invalid_password))
    end

    respond_with(@user)
  end

  # GET /users/1/redraw
  #----------------------------------------------------------------------------
  def redraw
    current_user.preference[:locale] = params[:locale]
    render :text => %Q{window.location.href = "#{user_path(current_user)}";}
  end

  # GET /users/opportunities_overview
  #----------------------------------------------------------------------------
  def opportunities_overview
    @users_with_opportunities = User.have_assigned_opportunities.order(:first_name)
    @unassigned_opportunities = Opportunity.unassigned.pipeline.order(:stage)
  end

end
