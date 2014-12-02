# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class RegistrationsController < EntitiesController
  before_filter :get_registrations, :only => [ :new, :create, :edit, :update ]
  before_filter :check_for_mobile
  before_filter :get_data_for_sidebar, :only => :index
  skip_before_filter :require_user, :only => [ :pay, :pay_submit, :pay_not_found ]
  
  def confirm
    respond_with(@contact)
  end
  
  def pay
    hashids = Hashids.new(Setting.token_salt, 8)
    @token = params[:token]
    @registration = Registration.find(hashids.decode(params[:token])[0])
    
  end
  
  def pay_submit
    hashids = Hashids.new(Setting.token_salt, 8)
    @token = params[:token]
    @registration = Registration.find(hashids.decode(params[:token])[0])
    
    charge = Stripe::Charge.create(
    :card => params[:stripeToken],
    :amount => @registration.fee.to_i * 100, #stripe expects amount in cents
    :description => "#{@registration.event.name} fee payment for #{@registration.contact.full_name}",
    :currency => "aud",
    :expand => ['balance_transaction']
    )
    
    #change payment method
    #update saasu invoice
    
  rescue Stripe::CardError => e
    flash[:error] = e.message
    redirect_to pay_registration_path(:token => @token)
  end
  
  def pay_not_found
  end
  
  # GET /contacts
  #----------------------------------------------------------------------------
  # def index
#     query = params.include?("query") ? session[:contacts_query] = params[:query] : session[:contacts_query]
#     #overwrite with nil if params "q" (advanced search)
#     query = nil if params.include?("q")
#     @contacts = get_contacts(:page => params[:page], :per_page => params[:per_page], :query => query)
#     
#     respond_with @contacts do |format|
#       format.xls { render :layout => 'header' }
#       format.csv { render :csv => @contacts }
#     end
#   end

  # GET /registrations/1
  # AJAX /registrations/1
  #----------------------------------------------------------------------------
  # def show
  #   respond_with(@registration)
  # end

  # GET /registrations/new
  #----------------------------------------------------------------------------
  def new
    @registration.attributes = {:user => current_user, :access => Setting.default_access}
    
    if params[:related]
      model = params[:related].sub(/_\d+/, "")
      id = params[:related].split('_').last #change required for models with _ in name e.g. contact_group
      if related = model.classify.constantize.my.find_by_id(id)
        instance_variable_set("@#{model}", related)
      else
        respond_to_related_not_found(model) and return
      end
    end

    respond_with(@registration)
  end

  # GET /contacts/1/edit                                                   AJAX
  #----------------------------------------------------------------------------
  def edit
    if params[:previous].to_s =~ /(\d+)\z/
      @previous = Registration.my.find_by_id($1) || $1.to_i
    end
    if params[:related]
      model = params[:related].sub(/_\d+/, "")
      id = params[:related].split('_').last #change required for models with _ in name e.g. contact_group
      if related = model.classify.constantize.my.find_by_id(id)
        instance_variable_set("@#{model}", related)
      else
        respond_to_related_not_found(model) and return
      end
    end

    respond_with(@registration)
  end

  # POST /registrations
  #----------------------------------------------------------------------------
  def create
    respond_with(@registration) do |format|
      if @registration.save_with_permissions(params)
        @registrations = get_registrations if called_from_index_page?
        get_data_for_sidebar
      end
    end
  end

  # PUT /registrations/1
  #----------------------------------------------------------------------------
  def update
    if params[:related]
      model = params[:related].sub(/_\d+/, "")
      id = params[:related].split('_').last #change required for models with _ in name e.g. contact_group
      if related = model.classify.constantize.my.find_by_id(id)
        instance_variable_set("@#{model}", related)
      else
        respond_to_related_not_found(model) and return
      end
    end
    
    respond_with(@registration) do |format|
      get_data_for_sidebar unless @registration.update_with_permissions(params)
    end
  end

  # DELETE /registrations/1
  #----------------------------------------------------------------------------
  def destroy
    if @registration.event.contact_group.present? && @registration.event.contact_group.contacts.find(@registration.contact.id)
      @registration.event.contact_group.contacts.delete(@registration.contact)
    end
    
    @registration.destroy

    respond_with(@registration) do |format|
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
    end
  end
  
  # PUT /registrations/1/attach
  #----------------------------------------------------------------------------
  # Handled by EntitiesController :attach

  # POST /registrations/1/discard
  #----------------------------------------------------------------------------
  # Handled by EntitiesController :discard

  # POST /registrations/auto_complete/query                                     AJAX
  #----------------------------------------------------------------------------
  # Handled by ApplicationController :auto_complete

  # POST /registrations/redraw                                                  AJAX
  #----------------------------------------------------------------------------
  def redraw
    current_user.pref[:contacts_per_page] = params[:per_page] if params[:per_page]

    # Sorting and naming only: set the same option for Leads if the hasn't been set yet.
    if params[:sort_by]
      current_user.pref[:contacts_sort_by] = Contact::sort_by_map[params[:sort_by]]
      if Lead::sort_by_fields.include?(params[:sort_by])
        current_user.pref[:leads_sort_by] ||= Lead::sort_by_map[params[:sort_by]]
      end
    end
    if params[:naming]
      current_user.pref[:contacts_naming] = params[:naming]
      current_user.pref[:leads_naming] ||= params[:naming]
    end

    @contacts = get_contacts(:page => 1, :per_page => params[:per_page]) # Start on the first page.
    set_options # Refresh options
    
    respond_with(@contacts) do |format|
      format.js { render :index }
    end
  end
  
  # POST /contacts/filter                                                  AJAX
  #----------------------------------------------------------------------------
  def filter
    session[:contacts_filter] = params[:folder] if params[:folder].present?
    session[:contacts_user_filter] = params[:user] if params[:user].present?
    
    respond_with(@contacts = get_contacts(:page => 1, :per_page => params[:per_page])) do |format|
      format.js { render :index }
    end
  end
  
  def options
    get_data_for_sidebar
    render :options
  end

  private
  #----------------------------------------------------------------------------
  alias :get_registrations :get_list_of_records

  def set_options
    super
  end
  
  #----------------------------------------------------------------------------
  def get_data_for_sidebar
    
  end

  #----------------------------------------------------------------------------
  def respond_to_destroy(method)
    if method == :ajax
      @registrations = get_registrations
      if called_from_index_page?
        
        if @registrations.blank?
          @registrations = get_registrations(:page => current_page - 1) if current_page > 1
          render :index and return
        end
      else
        self.current_page = 1
      end
      # At this point render destroy.js.rjs
    else
      self.current_page = 1
      flash[:notice] = t(:msg_asset_deleted, @registration.contact.full_name)
      redirect_to registrations_path #???
      
    end
  end
end
