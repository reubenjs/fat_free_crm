# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class AccountsController < EntitiesController
  before_filter :get_data_for_sidebar, :only => :index

  # GET /accounts
  #----------------------------------------------------------------------------
  def index
    inactive = params.include?("inactive") ? session[:accounts_inactive] = (params[:inactive] == "true") : session[:accounts_inactive]
    
    @accounts = get_accounts(:page => params[:page], :per_page => params[:per_page], :inactive => inactive)

    respond_with @accounts do |format|
      format.xls { render :layout => 'header' }
      format.csv { render :csv => @accounts }
    end
  end

  # GET /accounts/1
  # AJAX /accounts/1
  #----------------------------------------------------------------------------
  def show
    @sort = current_user.pref[:contacts_sort_by]
    @stage = Setting.unroll(:opportunity_stage)
    @comment = Comment.new
    @timeline = timeline(@account)
    respond_with(@account)
  end

  # GET /accounts/new
  #----------------------------------------------------------------------------
  def new
    @account.attributes = {:user => current_user, :access => Setting.default_access, :assigned_to => nil}

    if params[:related]
      model, id = params[:related].split('_')
      instance_variable_set("@#{model}", model.classify.constantize.find(id))
    end

    respond_with(@account)
  end

  # GET /accounts/1/edit                                                   AJAX
  #----------------------------------------------------------------------------
  def edit
    if params[:previous].to_s =~ /(\d+)\z/
      @previous = Account.my.find_by_id($1) || $1.to_i
    end

    respond_with(@account)
  end

  # POST /accounts
  #----------------------------------------------------------------------------
  def create
    @comment_body = params[:comment_body]
    respond_with(@account) do |format|
      if @account.save
        @account.add_comment_by_user(@comment_body, current_user)
        # None: account can only be created from the Accounts index page, so we
        # don't have to check whether we're on the index page.
        @accounts = get_accounts
        get_data_for_sidebar
      end
    end
  end

  # PUT /accounts/1
  #----------------------------------------------------------------------------
  def update
    respond_with(@account) do |format|
      # Must set access before user_ids, because user_ids= method depends on access value.
      @account.access = params[:account][:access] if params[:account][:access]
      get_data_for_sidebar if @account.update_attributes(params[:account])
    end
  end
  
  # GET /accounts/1/cold_contacts.xls
  #----------------------------------------------------------------------------
  def cold_contacts
    # generates a report showing whether each contact has been to TBT or a BSG in the last two weeks
    respond_with @account do |format|
      format.xls { render :layout => 'header' }
    end
  end
  
  #----------------------------------------------------------------------------
  def move_contact
    @contact = Contact.find(params[:contact_id])
    @contact.account = @account # confusing, but it's as good as I could figure out with the dropable helper
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
    
    # respond_with (@contact) do |format|
    #       redirect_to :contacts, :action => :move_contact and return
    #     end
    
  end

  # DELETE /accounts/1
  #----------------------------------------------------------------------------
  def destroy
    @account.destroy

    respond_with(@account) do |format|
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
    end
  end
  
  def archive
    @account = Account.find(params[:id])
    @account.update_attributes(:inactive => true) if @account
    
    respond_with(@account) do |format|
      get_data_for_sidebar
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
    end
  end
  
  def activate
    @account = Account.find(params[:id])
    @account.update_attributes(:inactive => false) if @account
    
    respond_with(@account) do |format|
      get_data_for_sidebar
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
    end
  end

  # PUT /accounts/1/attach
  #----------------------------------------------------------------------------
  # Handled by EntitiesController :attach

  # PUT /accounts/1/discard
  #----------------------------------------------------------------------------
  # Handled by EntitiesController :discard

  # POST /accounts/auto_complete/query                                     AJAX
  #----------------------------------------------------------------------------
  # Handled by ApplicationController :auto_complete

  # GET /accounts/redraw                                                   AJAX
  #----------------------------------------------------------------------------
  def redraw
    current_user.pref[:accounts_per_page] = params[:per_page] if params[:per_page]
    current_user.pref[:accounts_sort_by]  = Account::sort_by_map[params[:sort_by]] if params[:sort_by]
    @accounts = get_accounts(:page => 1, :per_page => params[:per_page], :inactive => session[:accounts_inactive])
    set_options # Refresh options

    respond_with(@accounts) do |format|
      format.js { render :index }
    end
  end
  
  # POST /accounts/redraw                                                  AJAX
  #----------------------------------------------------------------------------
  def redraw_show
    # current_user.pref[:contact_groups_per_page] = params[:per_page] if params[:per_page]
    # current_user.pref[:contact_groups_outline]  = params[:outline]  if params[:outline]
    current_user.pref[:contacts_sort_by]  = Contact::sort_by_map[params[:sort_by]] if params[:sort_by]
    @sort = current_user.pref[:contacts_sort_by]
    #set_options # Refresh options
    @sort = current_user.pref[:contacts_sort_by]
    if params[:query]
      @query, @tags = parse_query_and_tags(params[:query])
    end
    scope = @account.contacts
    scope = scope.text_search(@query) if @query.present?
    scope = scope.tagged_with(@tags, :on => :tags) if @tags.present?
    scope = scope.order(@sort) if @sort.present?
    
    @contacts = scope
    
    render :redraw_show
  end

  # POST /accounts/filter                                                  AJAX
  #----------------------------------------------------------------------------
  def filter
    session[:accounts_filter] = params[:category]
    @accounts = get_accounts(:page => 1, :per_page => params[:per_page], :inactive => session[:accounts_inactive])

    respond_with(@accounts) do |format|
      format.js { render :index }
    end
  end

private

  #----------------------------------------------------------------------------
  alias :get_accounts :get_list_of_records

  #----------------------------------------------------------------------------
  def respond_to_destroy(method)
    if method == :ajax
      @accounts = get_accounts
      get_data_for_sidebar
      if @accounts.empty?
        @accounts = get_accounts(:page => current_page - 1) if current_page > 1
        render :index and return
      end
      # At this point render default destroy.js
    else # :html request
      self.current_page = 1 # Reset current page to 1 to make sure it stays valid.
      flash[:notice] = t(:msg_asset_deleted, @account.name)
      redirect_to accounts_path
    end
  end

  #----------------------------------------------------------------------------
  def get_data_for_sidebar
    @account_category_total = Hash[
      Setting.account_category.map do |key|
        [ key, Account.my.where(:category => key.to_s).count ]
      end
    ]
    categorized = @account_category_total.values.sum
    @account_category_total[:all] = Account.my.count
    @account_category_total[:other] = @account_category_total[:all] - categorized
  end
end
