class Registration < ActiveRecord::Base
  
  belongs_to :user
  belongs_to :contact
  belongs_to :event
  
  accepts_nested_attributes_for :contact
  
  has_paper_trail :meta => { :related => :contact }, :ignore => [ :id, :created_at, :updated_at, :contact_id ]
  
  serialize :breakfasts, Array
  serialize :lunches, Array 
  serialize :dinners, Array
  serialize :sleeps, Array
  
  has_fields
  acts_as_taggable_on :tags
  uses_user_permissions
  has_paper_trail :ignore => [ :subscribed_users ]
  
  scope :created_by, lambda { |user| { :conditions => [ "user_id = ?", user.id ] } }
  
  sortable :by => [ "created_at DESC", "updated_at DESC" ], :default => "created_at DESC"
  
  validate :users_for_shared_access
  
  before_create :create_saasu_invoice

  # Default values provided through class methods.
  #----------------------------------------------------------------------------
  def self.per_page ; 20 ; end
  def self.outline ; "long" ; end

  # Respond to name
  def name
    self.event.name + " registration: " + self.contact.full_name
  end

  # Attach given attachment to the account if it hasn't been attached already.
  #----------------------------------------------------------------------------
  def attach!(attachment)
    unless self.send("#{attachment.class.name.downcase}_ids").include?(attachment.id)
      self.send(attachment.class.name.tableize) << attachment
    end
  end

  # Discard given attachment from the account.
  #----------------------------------------------------------------------------
  def discard!(attachment)
    if attachment.is_a?(Task)
      attachment.update_attribute(:asset, nil)
    else # Contacts, Opportunities
      self.send(attachment.class.name.tableize).destroy(attachment)
    end
  end
  
  # Backend handler for [Update Contact] form (see contact/update).
  #----------------------------------------------------------------------------
  def update_with_permissions(params)
    extend SaasuHandler
    #self.reload
    # Must set access before user_ids, because user_ids= method depends on access value.
    self.access = params[:registration][:access] if params[:registration][:access]
    self.attributes = params[:registration]
    
    if (self.fee.to_i > 0) || self.saasu_uid.present?
      update_saasu(self, params[:send_invoice].present?)
    end
    
    self.save
  end

  private
  
  def create_saasu_invoice
    extend SaasuHandler
    if self.fee.to_i > 0
      add_saasu(self) 
    end
  end
  
  # Make sure at least one user has been selected if the campaign is being shared.
  #----------------------------------------------------------------------------
  def users_for_shared_access
    errors.add(:access, :share_registration) if self[:access] == "Shared" && !self.permissions.any?
  end
  
  

end
