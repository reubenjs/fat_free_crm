# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class ContactsController < EntitiesController
  before_filter :get_accounts, :only => [ :new, :create, :edit, :update ]
  before_filter :check_for_mobile
  before_filter :get_data_for_sidebar, :only => :index
  
  def single_access_allowed?
    (action_name == "mailchimp_webhooks" || action_name == "mandrill_webhooks")
  end
  
  def confirm
    respond_with(@contact)
  end
  
  def mailing_lists
    @account = @contact.account || Account.new(:user => current_user)
    respond_with(@contact)
  end
  alias :tags :mailing_lists
  
  def mandrill_webhooks
    if request.post?
      data = JSON.parse(params['mandrill_events'])
      case data[0]['event']
      #just implementing hard bounce for now
      when "hard_bounce"
        contact = Contact.find_by_email(data[0]['msg']['email'])
        if contact.present?
          contact.tasks << Task.new(
                    :name => "Email bounced!", 
                    :category => :email, 
                    :bucket => "due_this_week", 
                    :user => @current_user , 
                    :assigned_to => User.find_by_first_name("geoff").id
                    )
          contact.comments << Comment.new(
                    :user_id => 1,
                    :comment => "Email bounced\nDescription: #{data[0]['msg']['bounce_description']}\nServer said: #{data[0]['msg']['diag']}"
                    )
        end
      end
    end
  end
  
  def mailchimp_webhooks
    if request.post?
      assigned_to_key = "other"
      
      unless params[:data]["merges"].nil? || params[:data]["merges"]["INTERESTS"].empty?
        list_name = params[:data]["merges"]["INTERESTS"].split(",")[0]
        assigned_to_key = list_name.downcase.underscore + "_" + params[:data]["merges"]["GENDER"].downcase
      end
      
      case params[:type]
      when "subscribe"
        if contact = Contact.find_or_create_by_email(params[:data][:email])
          if params[:data]["merges"]["INTERESTS"].present?
            contact.cf_weekly_emails = params[:data]["merges"]["INTERESTS"].split(",").collect(&:strip) 
          end
          contact.first_name = params[:data]["merges"]["FNAME"]
          contact.last_name = params[:data]["merges"]["LNAME"]
          contact.cf_gender = params[:data]["merges"]["GENDER"]
          contact.user = @current_user if contact.user.nil?
          contact.assigned_to = User.find_by_first_name(Setting.mailchimp[assigned_to_key.to_sym]).id
          contact.account = Account.find_by_name(list_name)
          contact.tasks << Task.new(
                  :name => "New signup to email list - send welcome email", 
                  :category => :email, 
                  :bucket => "due_this_week", 
                  :user => @current_user,
                  :assigned_to => contact.assigned_to
                  )
        end
      when "unsubscribe"
        if contact = Contact.find_by_email(params[:data][:email])
          contact.cf_weekly_emails = []
          contact.tasks << Task.new(
                  :name => "followup unsubscribe from mailchimp", 
                  :category => :follow_up, 
                  :bucket => "due_this_week", 
                  :user => @current_user,
                  :assigned_to => contact.assigned_to
                  )
        end
      when "upemail"
        if contact = Contact.find_by_email(params[:data][:old_email])
          contact.email = params[:data][:new_email]
        end
      when "profile" 
        if contact = Contact.find_by_email(params[:data][:email])
          contact.first_name = params[:data]["merges"]["FNAME"]
          contact.last_name = params[:data]["merges"]["LNAME"]
          if params[:data]["merges"]["INTERESTS"].present?
            contact.cf_weekly_emails = params[:data]["merges"]["INTERESTS"].split(",").collect(&:strip) 
          else
            contact.cf_weekly_emails = []
          end
        end
      when "cleaned"
        if contact = Contact.find_by_email(params[:data][:email])
          reason = params[:data][:reason] == "hard" ? "the email bounced" : "the email was reported as spam"
          contact.cf_weekly_emails = []
          contact.tasks << Task.new(:name => "unsubscribed from mailchimp becuase #{reason}", :category => :follow_up, :bucket => "due_this_week", :user => @current_user)
        end
      end
      contact.save
    else # GET
      respond_to do |format|
        format.all {head :ok, :content_type => 'text/html'}
      end
    end  
  end
  
  # GET /contacts
  #----------------------------------------------------------------------------
  def index
    query = params.include?("query") ? session[:contacts_query] = params[:query] : session[:contacts_query]
    #overwrite with nil if params "q" (advanced search)
    query = nil if params.include?("q")
    @contacts = get_contacts(:page => params[:page], :per_page => params[:per_page], :query => query)
    
    respond_with @contacts do |format|
      format.xls { render :layout => 'header' }
      format.csv { render :csv => @contacts }
    end
  end

  # GET /contacts/1
  # AJAX /contacts/1
  #----------------------------------------------------------------------------
  def show
    @stage = Setting.unroll(:opportunity_stage)
    @comment = Comment.new
    @timeline = timeline(@contact)
    @contact_groups = @contact.contact_groups
    @bsg_attendances = @contact.attendances.where('events.category = ?', "bsg").order('event_instances.starts_at DESC').includes(:event, :event_instance)
    @tbt_attendances = @contact.attendances.where('events.category = ?', "bible_talk").order('event_instances.starts_at DESC').includes(:event, :event_instance)
    @other_attendances = @contact.attendances.where('events.category NOT IN (?) OR events.category IS NULL', ["bsg", "bible_talk"]).order('event_instances.starts_at DESC').includes(:event, :event_instance)
    respond_with(@contact)
  end

  # GET /contacts/new
  #----------------------------------------------------------------------------
  def new
    @contact.attributes = {:user => current_user, :access => Setting.default_access, :assigned_to => nil}
    @account = Account.new(:user => current_user)
    if called_from_landing_page?(:event_instances)
      @event_instance = EventInstance.find(params[:event_instance_id])
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

    respond_with(@contact)
  end

  # GET /contacts/1/edit                                                   AJAX
  #----------------------------------------------------------------------------
  def edit
    @account = @contact.account || Account.new(:user => current_user)
    if params[:previous].to_s =~ /(\d+)\z/
      @previous = Contact.my.find_by_id($1) || $1.to_i
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

    respond_with(@contact)
  end

  # POST /contacts
  #----------------------------------------------------------------------------
  def create
    @comment_body = params[:comment_body]
    if called_from_landing_page?(:event_instances)
      @event_instance = EventInstance.find(params[:event_instance])
    end
    respond_with(@contact) do |format|
      if @contact.save_with_account_and_permissions(params)
        @contact.add_comment_by_user(@comment_body, current_user)
        @contacts = get_contacts if called_from_index_page?
        get_data_for_sidebar
        
        # used in create.rjs to refresh the "Email Group" link
        if request.referer =~ /\/contact_groups\/(.+)$/
          @contact_group = ContactGroup.find($1) # related contact_group
        end
      else
        # used for contact/create in show/contact_group view
        if params[:related]
          model = params[:related].sub(/_\d+/, "")
          id = params[:related].split('_').last #change required for models with _ in name e.g. contact_group
          if related = model.classify.constantize.my.find_by_id(id)
            instance_variable_set("@#{model}", related)
          else
            respond_to_related_not_found(model) and return
          end
        end
        unless params[:account][:id].blank?
          @account = Account.find(params[:account][:id])
        else
          if request.referer =~ /\/accounts\/(\d+)\z/
            @account = Account.find($1) # related account
          else
            @account = Account.new(:user => current_user)
          end
        end
        @opportunity = Opportunity.my.find(params[:opportunity]) unless params[:opportunity].blank?
      end
    end
  end

  # PUT /contacts/1
  #----------------------------------------------------------------------------
  def update
    # used for contact/edit in event_instance (attendance) view
    if params[:related]
      model = params[:related].sub(/_\d+/, "")
      id = params[:related].split('_').last #change required for models with _ in name e.g. contact_group
      if related = model.classify.constantize.my.find_by_id(id)
        instance_variable_set("@#{model}", related)
      else
        respond_to_related_not_found(model) and return
      end
    end
    
    # used in update.rjs to refresh the "Email Group" link
    if request.referer =~ /\/contact_groups\/(.+)$/
      @contact_group = ContactGroup.find($1) # related contact_group
    end
    
    respond_with(@contact) do |format|
      unless @contact.update_with_account_and_permissions(params)
        if @contact.account
          @account = Account.find(@contact.account.id)
        else
          @account = Account.new(:user => current_user)
        end
      else
        get_data_for_sidebar
      end
    end
  end

  def move_contact
    
  end

  # DELETE /contacts/1
  #----------------------------------------------------------------------------
  def destroy
    # used in destroy.rjs to refresh the "Email Group" link
    if request.referer =~ /\/contact_groups\/(.+)$/
      @contact_group = ContactGroup.find($1) # related contact_group
    end
    
    @contact.destroy

    respond_with(@contact) do |format|
      get_data_for_sidebar
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
    end
  end
  
  def graduate
    params.merge!({"contact" => {
        #"id" => params[:id], 
        "cf_year_graduated" => Setting.graduate[:year],
        "cf_weekly_emails" => [""]
        }})
    params.merge!({"account" => {"id" => Account.find_by_name(Setting.graduate[:account]).id }})
    
    @contact.update_with_account_and_permissions(params)
    
    respond_with(@contact) do |format|
      get_data_for_sidebar
    end
  end

  def attendances
    
  end
  # PUT /contacts/1/attach
  #----------------------------------------------------------------------------
  # Handled by EntitiesController :attach

  # POST /contacts/1/discard
  #----------------------------------------------------------------------------
  # Handled by EntitiesController :discard

  # POST /contacts/auto_complete/query                                     AJAX
  #----------------------------------------------------------------------------
  # Handled by ApplicationController :auto_complete

  # GET /contacts/redraw                                                   AJAX
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
    if params[:folders].present?
      session[:contacts_filter] = params[:folders].join(",")
    else
      update_session(:contacts_filter) do |filters| 
        if params[:checked].true?
          filters << params[:folder]
        else
          filters.delete(params[:folder])
        end
      end
    end

    if params[:users].present?
      session[:contacts_user_filter] = params[:users].join(",")
    else
      update_session(:contacts_user_filter) do |filters|      
        if params[:checked].true?
          filters << params[:user]
        else
          filters.delete(params[:user])
        end
      end
    end
    
    respond_with(@contacts = get_contacts(:page => 1, :per_page => params[:per_page])) do |format|
      format.js { render :index }
    end
  end
  
  def options
    get_data_for_sidebar
    render :options
  end

  private
  
  # Yields array of current filters and updates the session using new values.
  #----------------------------------------------------------------------------
  def update_session(name)
    #name = "contacts_filter"
    filters = (session[name].nil? ? [] : session[name].split(","))
    yield filters
    session[name] = filters.uniq.join(",")
  end
  
  #----------------------------------------------------------------------------
  alias :get_contacts :get_list_of_records

  #----------------------------------------------------------------------------
  def get_accounts
    @accounts = Account.my.order('name')
  end

  def set_options
    super
    @naming = (current_user.pref[:contacts_naming]   || Contact.first_name_position) unless params[:cancel].true?
  end
  
  #----------------------------------------------------------------------------
  def get_data_for_sidebar
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

  #----------------------------------------------------------------------------
  def respond_to_destroy(method)
    if method == :ajax
      if called_from_index_page?
        @contacts = get_contacts
        if @contacts.blank?
          @contacts = get_contacts(:page => current_page - 1) if current_page > 1
          render :index and return
        end
      else
        self.current_page = 1
      end
      # At this point render destroy.js
    else
      self.current_page = 1
      flash[:notice] = t(:msg_asset_deleted, @contact.full_name)
      redirect_to contacts_path
    end
  end
end
