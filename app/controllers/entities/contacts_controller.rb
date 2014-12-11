# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class ContactsController < EntitiesController
  before_filter :get_accounts, :only => [ :new, :create, :edit, :update, :archive, :activate ]
  before_filter :check_for_mobile
  before_filter :get_data_for_sidebar, :only => :index
  
  def single_access_allowed?
    (action_name == "mailchimp_webhooks" || action_name == "mandrill_webhooks" || action_name == "bsg_webhooks" || action_name == "myc_webhooks")
  end
  
  def confirm
    @discard_text = params[:discard_text] || "remove"
    respond_with(@contact)
  end
  alias :confirm_discard :confirm
  
  def mailing_lists
    @account = @contact.account || Account.new(:user => current_user)
    respond_with(@contact)
  end
  alias :tags :mailing_lists
  
  def myc_webhooks
    if request.post?
  
      event = Event.find_or_initialize_by_name(
          :name => "Commencement Camp 2015",
          :access => Setting.default_access,
          :user_id => 1,
          :category => "conference",
          :has_registrations => true
          )
        unless event.persisted?
          event.save
          ei = EventInstance.new(
            :access => Setting.default_access,
            :user_id => 1,
            :name => "Commencement Camp 2015",
            :location => "Dzintari"
            #:starts_at => DateTime.parse("2013-07-22 10:00:00"),
            #:ends_at => DateTime.parse("2013-07-26 10:00:00")
            )
            ei.calendar_start_date = "17/02/2015"
            ei.calendar_start_time = "10:00am"
            ei.calendar_end_date = "20/02/2015"
            ei.calendar_end_time = "2:00pm"
        
          event.event_instances << ei
        end
      
      # Find or create contact
      #------------------------
    
      contact = Contact.find_by_email(params[:email])
      if contact.nil?
        contact = Contact.find_or_initialize_by_mobile(params[:phone].gsub(/[\(\) ]/, ""))
        contact.update_attributes(:alt_email => contact.email) if contact.persisted? #email must have changed
        log_string = "Contact found by mobile. Registered: "
      end
    
      unless registration = event.registrations.find_by_contact_id(contact.id)         
        
        # Create the registration if not found
        #-------------------------------------
    
        registration = Registration.new(
          :contact => contact, 
          :event => event,
          :access => Setting.default_access,
          :user_id => 1,
          )
    
      end
    
      # Pull in contact data
      #----------------------
    
      contact.business_address = Address.new
      contact.business_address.street1 = params[:address][:thoroughfare]
      contact.business_address.street2 = params[:address][:premise]
      contact.business_address.city = params[:address][:locality]
      contact.business_address.state = params[:address][:administrative_area]
      contact.business_address.zipcode = params[:address][:postal_code]
      contact.business_address.country = "Australia"
      contact.business_address.address_type = "Business"   
    
      unless contact.assigned_to.present?
        if (params[:campus] == "city_east" || params[:campus] == "city_west")
          #contact.cf_weekly_emails << row[:_campus] unless contact.cf_weekly_emails.include?(row[:_campus])
          user = (params[:gender] == "male") ? User.find_by_first_name("dave") : User.find_by_first_name("emily")
        elsif (params[:campus] == "adelaide")
          #contact.cf_weekly_emails << row[:_campus] unless contact.cf_weekly_emails.include?(row[:_campus])
          user = (params[:gender] == "male") ? User.find_by_first_name("reuben") : User.find_by_first_name("laura")
        else
          user = User.find_by_first_name("geoff")
        end
        contact.assigned_to = user.id
      end
    
      unless contact.account.present?
        contact.account = Account.find_or_create_by_name(params[:campus].titleize) 
        contact.account.user = User.find(1)
      end
    
      if !contact.persisted?
        contact.user_id = 1
        contact.access = Setting.default_access
        contact.tag_list << "new@cc15" unless contact.tag_list.include?("new@cc15")
        log_string = "Created new contact: "
      else
        log_string = "Contact found by email. Registered: " if log_string.nil?
      end
      
      contact.update_attributes(
        :first_name => params[:first_name],
        :preferred_name => params[:preferred_name].gsub(/N\/A/, ""),
        :last_name => params[:last_name],
        :email => params[:email],
        :cf_gender => params[:gender].titleize,
        #:phone => row[:_home_phone],
        :mobile => params[:phone].gsub(/[\(\) ]/, ""),
        #address?
        :cf_faculty => params[:faculty].gsub(/N\/A/, ""),
        :cf_campus => params[:campus].titleize,
        :cf_course_1 => (params[:course].blank? or params[:course] == "N/A") ? nil : params[:course][:name],
        :cf_church_affiliation => params[:church].gsub(/N\/A/, ""),
        #:cf_denomination => params[:denomination].gsub(/N\/A/, ""),
        :cf_expected_grad_year => (params[:expected_graduation_year] == 'N/A or unknown' ? nil : params[:expected_graduation_year]),
        :cf_has_dietary_or_health_issues => (params[:dietary_requirements] == "yes" || params[:health_issues] == "yes"),
        :cf_dietary_health_issue_details => "Dietary requirements: #{params[:please_specify_dietary]} \r\nHealth issues: #{params[:health_issues_specify]}",
        :cf_emergency_contact => params[:emergency_contact_name],
        :cf_emergency_contact_relationship => params[:emergency_contact_relationship],
        :cf_emergency_contact_number => params[:emergency_contact_phone],
        :facebook_uid => params[:facebook_user],
        :facebook_token => params[:facebook_token],
        :facebook => (params[:facebook_user] != nil ? "fb.com/#{params[:facebook_user]}" : nil),
        :school => (params[:highschool].blank? or params[:highschool] == "N/A") ? nil : params[:highschool][:name],
        :referral_source_info => params[:source_info],
        :referral_source => (params[:first_time] == "yes" and contact.referral_source.blank?) ? "Commencement Camp 2015" : contact.referral_source
       )
      
      if contact.first_name == contact.preferred_name
        contact.preferred_name = nil
      end

      if params[:first_time] == "yes"
        contact.tag_list << "first-cc-2015" unless contact.tag_list.include?("first-cc-2015")
        registration.assign_attributes(:first_time => true)
      end
    
      if params[:part_time] == "yes"
        contact.tag_list << "part_time@cc15" unless contact.tag_list.include?("part_time@cc15")
        registration.assign_attributes(:part_time => true)
      end
    
      if params[:financial_assistance] == "yes"
        registration.assign_attributes(:need_financial_assistance => true)
        contact.tasks << Task.new(
              :name => "Requires financial assistance", :category => :follow_up, :bucket => "due_this_week", :user => User.find_by_first_name("emily")
              )
      end
      
      contact.save
    
      # Pull in registration data
      #---------------------------
    
      registration.assign_attributes(
        :transport_required => (params[:transport_required] == "yes"),
        :driver_for => params[:driver_for],
        :can_transport => params[:drive_others],
        :donate_amount => params[:donate_amount],
        :t_shirt_ordered => (params[:purchase_jumper] == "yes" ? 1 : 0),
        :t_shirt_size_ordered => params[:jumper_size],
        #:payment_method => (params[:payment_method] == "paypal_wps" ? "PayPal" : "Cash"),
        :payment_method => (params[:payment_method] == "commerce_stripe" ? "Online" : "Cash"),
        :fee => params[:total_amount].to_i / 100,
        :breakfasts => (params[:breakfast].blank? ? nil : params[:breakfast].split(", ")),
        :lunches => (params[:lunch].blank? ? nil : params[:lunch].split(", ")),
        :dinners => (params[:dinner].blank? ? nil : params[:dinner].split(", ")),
        :sleeps => (params[:sleeping].blank? ? nil : params[:sleeping].split(", ")),
        :international_student => (params[:international_student] == "yes"),
        :requires_sleeping_bag => (params[:sleeping_bag_required] == "yes"),
        :discount_allowed => Setting.conference[:earlybird_active]
      )
              
      # There is now enough info in registration for observers/registration_observer 
      # to raise an invoice
      #-------------------------
    
      if registration.save
    
        # Check for suspected duplicate contacts after syncing this item
        # --------------------------------------------------------------- 
    
        contacts_with_name = Contact.where(:first_name => contact.first_name, :last_name => contact.last_name)
        if contacts_with_name.size > 1
          contact.tasks << Task.new(
                :name => "Possible duplicate from registration sync", :category => :follow_up, :bucket => "due_this_week", :user => User.find_by_first_name("reuben")
                )
        end
        
        respond_to do |format|
          format.all {head :ok, :content_type => 'text/html'}
        end
        
      else
        #puts "Registration failed for #{contact.first_name} #{contact.last_name}"
        UserMailer.delay.saasu_registration_error(contact, "CC registration save failed")
        
        respond_to do |format|
          format.all {head 500, :content_type => 'text/html'}
        end
      end
      
    else # GET
      respond_to do |format|
        format.all {head :ok, :content_type => 'text/html'}
      end
    end
  end
  
  def bsg_webhooks
    if request.post?
      #Setup groups if they don't already exist
      adelaide_group = ContactGroup.find_or_initialize_by_name(
          :name => Setting.bsg[:adelaide_group_name],
          :access => Setting.default_access,
          :user_id => 1
          )
      unless adelaide_group.persisted?
        adelaide_group.save
      end
        
      ce_group = ContactGroup.find_or_initialize_by_name(
          :name => Setting.bsg[:city_east_group_name],
          :access => Setting.default_access,
          :user_id => 1
          )
      unless ce_group.persisted?
        ce_group.save
      end
      
      cw_group = ContactGroup.find_or_initialize_by_name(
          :name => Setting.bsg[:city_west_group_name],
          :access => Setting.default_access,
          :user_id => 1
          )
      unless cw_group.persisted?
        cw_group.save
      end
      
      contact = params[:email].blank? ? nil : Contact.find_by_email(params[:email])
      if contact.nil?
        if params[:phone].blank?
          contact = Contact.new
          log_string = "Contact initialized"
        else
          contact = Contact.find_or_initialize_by_mobile(params[:phone].gsub(/[\(\) ]/, ""))
          contact.update_attributes(:alt_email => contact.email) if contact.persisted? #email must have changed
          log_string = "Contact found by mobile. updated: "
        end
      end
      
      if params[:year] == "1"
        contact.cf_year_commenced = Time.new.year
      end  
      
      unless contact.assigned_to.present?
        if (params[:campus] == "city_east" || params[:campus] == "city_west")
          #contact.cf_weekly_emails << row[:_campus] unless contact.cf_weekly_emails.include?(row[:_campus])
          user = (params[:gender] == "Male") ? User.find_by_first_name("dave") : User.find_by_first_name("emily")
        elsif (params[:campus] == "adelaide")
          #contact.cf_weekly_emails << row[:_campus] unless contact.cf_weekly_emails.include?(row[:_campus])
          user = (params[:gender] == "Male") ? User.find_by_first_name("reuben") : User.find_by_first_name("laura")
        else
          user = User.find_by_first_name("geoff")
        end
        contact.assigned_to = user.id
      end
      
      unless contact.account.present?
        contact.account = Account.find_or_create_by_name(params[:campus].titleize) 
        contact.account.user = User.find(1)
      end
      
      if !contact.persisted?
        contact.user_id = 1
        contact.access = Setting.default_access
        contact.tag_list << "new@bsg#{Time.new.strftime('%y')}" unless contact.tag_list.include?("new@bsg#{Time.new.strftime('%y')}")
        log_string = "Created new contact: "
      else
        log_string = "Contact found by email. updated: " if log_string.nil?
      end

      contact.tag_list << params[:opportunities].split(", ") if params[:opportunities]
      
      unless params[:instrument].blank?
        contact.background_info << "\n" unless contact.background_info.blank?
        contact.background_info = contact.background_info.to_s + "Instrument played: #{params[:instrument]}"
      end
      
      contact.update_attributes(
        :first_name => params[:first_name],
        :last_name => params[:last_name],
        :email => params[:email],
        :cf_gender => params[:gender],
        :mobile => params[:phone].gsub(/[\(\) ]/, ""),
        #address?
        :cf_campus => params[:campus].titleize,
        :cf_course_1 => params[:course],
        :cf_faculty => params[:faculty]
      )
      
      contact.cf_weekly_emails << params[:campus].titleize unless contact.cf_weekly_emails.include?(params[:campus].titleize)
      
      contact.save!
      contact.touch
      
      contacts_with_name = Contact.where(:first_name => contact.first_name, :last_name => contact.last_name)
      if contacts_with_name.size > 1
        contact.tasks << Task.new(
              :name => "Possible duplicate from bsg registration sync", :category => :follow_up, :bucket => "due_this_week", :user => User.find_by_first_name("reuben")
              )
      end
      
      adelaide_group.contacts << contact if params[:campus] == "adelaide" && !adelaide_group.contacts.include?(contact) #shouldn't happen, but just in case
      ce_group.contacts << contact if params[:campus] == "city_east" && !ce_group.contacts.include?(contact) #shouldn't happen, but just in case
      cw_group.contacts << contact if params[:campus] == "city_west" && !cw_group.contacts.include?(contact) #shouldn't happen, but just in case
      
      #TODO: add to emailing lists
      
      respond_to do |format|
        format.all {head :ok, :content_type => 'text/html'}
      end
      
    else # GET
      respond_to do |format|
        format.all {head :ok, :content_type => 'text/html'}
      end
    end
  end
  
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
    inactive = params.include?("inactive") ? session[:contacts_inactive] = (params[:inactive] == "true") : session[:contacts_inactive]
    
    @contacts = get_contacts(:page => params[:page], :per_page => params[:per_page], :query => query, :inactive => inactive)

    #@inactive_only = inactive
    
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
  
  def archive
    @contact = Contact.find(params[:id])
    @contact.update_attributes(:inactive => true) if @contact
    
    respond_with(@contact) do |format|
      get_data_for_sidebar
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
    end
  end
  
  def activate
    @contact = Contact.find(params[:id])
    @contact.update_attributes(:inactive => false) if @contact
    
    respond_with(@contact) do |format|
      get_data_for_sidebar
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
    end
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

    @contacts = get_contacts(:page => 1, :per_page => params[:per_page], :inactive => session[:contacts_inactive]) # Start on the first page.
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
    
    respond_with(@contacts = get_contacts(:page => 1, :per_page => params[:per_page], :inactive => session[:contacts_inactive])) do |format|
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
