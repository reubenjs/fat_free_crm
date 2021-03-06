# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
# == Schema Information
#
# Table name: contacts
#
#  id              :integer         not null, primary key
#  user_id         :integer
#  lead_id         :integer
#  assigned_to     :integer
#  reports_to      :integer
#  first_name      :string(64)      default(""), not null
#  last_name       :string(64)      default(""), not null
#  access          :string(8)       default("Public")
#  title           :string(64)
#  department      :string(64)
#  source          :string(32)
#  email           :string(64)
#  alt_email       :string(64)
#  phone           :string(32)
#  mobile          :string(32)
#  fax             :string(32)
#  blog            :string(128)
#  linkedin        :string(128)
#  facebook        :string(128)
#  twitter         :string(128)
#  born_on         :date
#  do_not_call     :boolean         default(FALSE), not null
#  deleted_at      :datetime
#  created_at      :datetime
#  updated_at      :datetime
#  background_info :string(255)
#  skype           :string(128)
#

class Contact < ActiveRecord::Base
  belongs_to  :user
  belongs_to  :lead
  belongs_to  :assignee, :class_name => "User", :foreign_key => :assigned_to
  belongs_to  :reporting_user, :class_name => "User", :foreign_key => :reports_to
  has_one     :account_contact, :dependent => :destroy
  has_one     :account, :through => :account_contact
  has_many    :registrations, :dependent => :destroy
  has_many    :contact_opportunities, :dependent => :destroy
  has_many    :opportunities, :through => :contact_opportunities, :uniq => true, :order => "opportunities.id DESC"
  has_many    :tasks, :as => :asset, :dependent => :destroy
  has_one     :business_address, :dependent => :destroy, :as => :addressable, :class_name => "Address", :conditions => "address_type = 'Business'"
  has_many    :addresses, :dependent => :destroy, :as => :addressable, :class_name => "Address" # advanced search uses this
  has_many    :emails, :as => :mediator
  has_many    :contact_groups, :through => :memberships
  has_many    :memberships
  
  ##what about when you delete a contact? do you want to lose all attendance records?
  #might be better to have an archive system for contacts so that deletion is only for
  #contacts we really don't want to keep any trace of...
  has_many    :attendances, :dependent => :destroy 

  delegate :campaign, :to => :lead, :allow_nil => true

  has_ransackable_associations %w(account opportunities tags activities emails addresses comments tasks contact_groups)
  ransack_can_autocomplete
  
  serialize :subscribed_users, Set

  accepts_nested_attributes_for :business_address, :allow_destroy => true, :reject_if => proc {|attributes| Address.reject_address(attributes)}

  scope :created_by,  ->(user) { where( user_id: user.id ) }
  scope :assigned_to, ->(user) { where( assigned_to: user.id ) }

  scope :show_inactive, lambda {|inactive| where( "#{inactive ? "contacts.inactive = true" : "contacts.inactive = false OR contacts.inactive IS NULL"}") }

  scope :text_search, ->(query) {
    t = Contact.arel_table
    # We can't always be sure that names are entered in the right order, so we must
    # split the query into all possible first/last name permutations.
    name_query = if query.include?(" ")
      scope, *rest = query.name_permutations.map{ |first, last|
        t[:first_name].matches("%#{first}%").and(t[:last_name].matches("%#{last}%"))
      }
      rest.map{|r| scope = scope.or(r)} if scope
      scope
    else
      t[:first_name].matches("%#{query}%").or(t[:last_name].matches("%#{query}%")).or(t[:preferred_name].matches("%#{query}%"))
    end

    other = t[:email].matches("%#{query}%").or(t[:alt_email].matches("%#{query}%"))
    other = other.or(t[:phone].matches("%#{query}%")).or(t[:mobile].matches("%#{query}%"))

    where( name_query.nil? ? other : name_query.or(other) )
  }
  
  scope :state, lambda { |filters|
    includes(:account_contact).where('account_contacts.account_id IN (?)' + (filters.delete('other') ? ' OR account_contacts.account_id IS NULL ' : ''), filters)
  }
  
  scope :user_state, lambda { |filters|
    where('contacts.assigned_to IN (?)' + (filters.delete('other') ? ' OR contacts.assigned_to IS NULL ' : ''), filters)
  }
  
  scope :in_accounts, lambda { |accounts|
    includes(:account_contact).where('account_contacts.account_id IN (?)', accounts)
  }
  
  uses_user_permissions
  acts_as_commentable
  uses_comment_extensions
  acts_as_taggable_on :tags
  has_paper_trail :ignore => [ :subscribed_users ]

  has_fields
  exportable
  sortable :by => [ "first_name ASC",  "last_name ASC", "created_at DESC", "updated_at DESC" ], :default => "created_at DESC"

  validates_presence_of :first_name, :message => :missing_first_name, :if => -> { Setting.require_first_names }
  validates_presence_of :last_name,  :message => :missing_last_name,  :if => -> { Setting.require_last_names  }
  validate :users_for_shared_access

  # Default values provided through class methods.
  #----------------------------------------------------------------------------
  def self.per_page ; 20                  ; end
  def self.first_name_position ; "before" ; end

  #----------------------------------------------------------------------------
  def full_name(format = nil)
    if format.nil? || format == "before"
      if !self.cf_mailing_first_name.blank? && self.cf_mailing_first_name != self.first_name
        "#{self.first_name} #{self.last_name} (#{self.cf_mailing_first_name})"
      else
        "#{self.first_name} #{self.preferred_name.present? ? "(#{self.preferred_name}) " : ""}#{self.last_name}"
      end
    else
      "#{self.last_name}, #{self.first_name} #{self.preferred_name.present? ? "(#{self.preferred_name})" : ""}"
    end
  end
  alias :name :full_name
  
  def has_mailchimp_subscription?
    !self.cf_weekly_emails[0].blank? && !self.email.blank?
  end
  
  def has_subscription?
    has_mailchimp_subscription? || !self.cf_supporter_emails[0].blank?
  end
  
  def last_attendance_at_event_category(event_type)
    events = Event.show_inactive(false).find_all_by_category(event_type)
    last_attendance = self.attendances.where('events.id IN (?)', events.each.map(&:id)).order('event_instances.starts_at DESC').includes(:event, :event_instance).first
    last_time = last_attendance.event_instance.starts_at unless last_attendance.nil?
  end
  
  def attendance_by_week_at_event_category(event_type, semester = 1)
    events = Event.show_inactive(false).find_all_by_category(event_type)
    attendances = self.attendances.where('events.id IN (?) AND events.semester = ?', events.each.map(&:id), semester).order('event_instances.starts_at DESC').includes(:event, :event_instance)

    attendance_array = Array.new(13){""} #will end up as something like ["", "", bullet, "" ...]
    attendances.each do |a|
      a.event_instance.name.scan(/week (\d+)/)
      if $1
        attendance_array[$1.to_i - 1] = "\u{2022}"
      end
    end
    attendance_array
  end
  
  def current_bsg
    current_bsg = ""
    
    groups = self.contact_groups.where(:inactive => false, :category => "bsg")
    groups.each do |g|
      if g.name.include?("BSG14S2-")
        current_bsg = g.name.split("-")[2]
      end
    end
    current_bsg
  end
  
  def registered_for?(event_id)
    self.registrations.map(&:event_id).include?(event_id)
  end

  # Backend handler for [Create New Contact] form (see contact/create).
  #----------------------------------------------------------------------------
  def save_with_account_and_permissions(params)
    save_account(params)
    result = self.save
    self.opportunities << Opportunity.find(params[:opportunity]) unless params[:opportunity].blank?
    self.contact_groups << ContactGroup.find(params[:contact_group]) unless params[:contact_group].blank?
    #if has_mailchimp_subscription?
    #  mailchimp_lists unless self.invalid?
    #end
    result
  end
  
  def subscriptions_in_words
    if has_subscription?
      subs = "subscriptions: "
      items = [""]
      if !self.cf_weekly_emails[0].blank?
        items << "Adl" if self.cf_weekly_emails.include? "Adelaide"
        items << "CE" if self.cf_weekly_emails.include? "City East"
        items << "CW" if self.cf_weekly_emails.include? "City West"
      end
      if !self.cf_supporter_emails[0].blank?
        items << "TT" if self.cf_supporter_emails.include? "TT Email"
        items << "TT (mail)" if self.cf_supporter_emails.include? "TT Mail"
        items << "PP" if self.cf_supporter_emails.include? "Prayer Points"
      end
      subs += items.length > 1 ? items.reject(&:blank?).join(", ") : items[0]
    else
      subs = ""
    end
  end
  
  def merge_hook(duplicate)
    if duplicate.saasu_uid.present?
      invoices_for_contact = Saasu::Invoice.all(
        :request_url => "invoiceList",
        :contactUid => duplicate.saasu_uid,
        :paidStatus => "all",
        :invoiceDateFrom => "2000-01-01T00:00",
        :invoiceDateTo => Date.today
      )
      
      invoices_for_contact += Saasu::Invoice.all(
        :request_url => "invoiceList",
        :transaction_type => "p",
        :contactUid => duplicate.saasu_uid,
        :paidStatus => "all",
        :invoiceDateFrom => "2000-01-01T00:00",
        :invoiceDateTo => Date.today
      )
    
      invoices_for_contact.each do |i|
        invoice_to_update = Saasu::Invoice.find(i.uid)
        invoice_to_update.contact_uid = self.saasu_uid
        Saasu::Invoice.update(invoice_to_update)
      end
      
      Saasu::Contact.delete(duplicate.saasu_uid)
    end
  end

  # Backend handler for [Update Contact] form (see contact/update).
  #----------------------------------------------------------------------------
  def update_with_account_and_permissions(params)
    save_account(params)
    # Must set access before user_ids, because user_ids= method depends on access value.
    self.access = params[:contact][:access] if params[:contact][:access]
    self.attributes = params[:contact]
    self.save
  end

  # Attach given attachment to the contact if it hasn't been attached already.
  #----------------------------------------------------------------------------
  def attach!(attachment)
    unless self.send("#{attachment.class.name.underscore.downcase}_ids").include?(attachment.id)
      self.send(attachment.class.name.tableize) << attachment
    end
  end

  # Discard given attachment from the contact.
  #----------------------------------------------------------------------------
  def discard!(attachment)
    if attachment.is_a?(Task)
      attachment.update_attribute(:asset, nil)
    else # Opportunities
      self.send(attachment.class.name.tableize).delete(attachment)
    end
  end

  # Class methods.
  #----------------------------------------------------------------------------
  def self.create_for(model, account, opportunity, params)
    attributes = {
      :lead_id     => model.id,
      :user_id     => params[:account][:user_id],
      :assigned_to => params[:account][:assigned_to],
      :access      => params[:access]
    }
    %w(first_name last_name title source email alt_email phone mobile blog linkedin facebook twitter skype do_not_call background_info).each do |name|
      attributes[name] = model.send(name.intern)
    end

    contact = Contact.new(attributes)

    # Set custom fields.
    if model.class.respond_to?(:fields)
      model.class.fields.each do |field|
        if contact.respond_to?(field.name)
          contact.send "#{field.name}=", model.send(field.name)
        end
      end
    end

    contact.business_address = Address.new(:street1 => model.business_address.street1, :street2 => model.business_address.street2, :city => model.business_address.city, :state => model.business_address.state, :zipcode => model.business_address.zipcode, :country => model.business_address.country, :full_address => model.business_address.full_address, :address_type => "Business") unless model.business_address.nil?

    # Save the contact only if the account and the opportunity have no errors.
    if account.errors.empty? && opportunity.errors.empty?
      # Note: contact.account = account doesn't seem to work here.
      contact.account_contact = AccountContact.new(:account => account, :contact => contact) unless account.id.blank?
      if contact.access != "Lead" || model.nil?
        contact.save
      else
        contact.save_with_model_permissions(model)
      end
      contact.opportunities << opportunity unless opportunity.id.blank? # must happen after contact is saved
    end
    contact
  end

  private
  # Make sure at least one user has been selected if the contact is being shared.
  #----------------------------------------------------------------------------
  def users_for_shared_access
    errors.add(:access, :share_contact) if self[:access] == "Shared" && !self.permissions.any?
  end

  # Handles the saving of related accounts
  #----------------------------------------------------------------------------
  def save_account(params)
    if params[:account][:id] == "" || params[:account][:name] == ""
      self.account = nil
    else
      account = Account.create_or_select_for(self, params[:account])
      if self.account != account and account.id.present?
        self.account_contact = AccountContact.new(:account => account, :contact => self)
      end
    end
    self.reload unless self.new_record? # ensure the account association is updated
  end

  ActiveSupport.run_load_hooks(:fat_free_crm_contact, self)
end
