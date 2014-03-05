class Event < ActiveRecord::Base
  attr_accessor :repeating_event #, :semester
  
  belongs_to :user
  belongs_to :assignee, :class_name => "User", :foreign_key => :assigned_to
  has_many :tasks, :as => :asset, :dependent => :destroy#, :order => 'created_at DESC'
  has_many :registrations, :dependent => :destroy
  has_many    :emails, :as => :mediator
  belongs_to :contact_group
  has_many :contacts, :through => :registrations
  has_many :event_instances, :dependent => :destroy
  accepts_nested_attributes_for :event_instances
  
  serialize :subscribed_users, Set

  scope :created_by, lambda { |user| { :conditions => [ "user_id = ?", user.id ] } }
  scope :assigned_to, lambda { |user| { :conditions => ["assigned_to = ?", user.id ] } }
  scope :state, lambda { |filters|
    where('category IN (?)' + (filters.delete('other') ? ' OR category IS NULL' : ''), filters)
  }
  scope :text_search, lambda { |query|
    query = query.gsub(/[^\w\s\-\.'\p{L}]/u, '').strip
    where('upper(name) LIKE upper(?)', "%#{query}%")
  }
  
  scope :show_inactive, lambda {|inactive| where( "#{inactive ? "inactive = true" : "inactive = false OR inactive IS NULL"}") }
  
  has_ransackable_associations %w(contacts tags comments tasks)
  ransack_can_autocomplete

  uses_user_permissions
  acts_as_commentable
  uses_comment_extensions
  acts_as_taggable_on :tags
  has_paper_trail :ignore => [ :subscribed_users ]
  has_fields
  exportable
  sortable :by => [ "name ASC", "created_at DESC", "updated_at DESC" ], :default => "created_at DESC"

  validates_presence_of :name, :message => :missing_name
  validate :users_for_shared_access
  
  
  before_save :nullify_blank_category

  # Default values provided through class methods.
  #----------------------------------------------------------------------------
  def self.per_page ; 20 ; end
  def self.outline ; "long" ; end
  
  def full_name
    self.name
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
  
  def contacts_accommodated_on(day)
    if self.registrations.any?
      contacts = self.contacts.where('registrations.sleeps LIKE (?) OR registrations.part_time = false', "%#{day}%") #.map{|r| r.contact} 
    end   
  end
  
  def contacts_eating_at(meal, day)
    if self.registrations.any?
      t = Registration.arel_table
      contacts = self.contacts.where(t[meal.pluralize.to_sym].matches("%#{day}%").or(t[:part_time].eq(false)))#.map{|r| r.contact}
    end
  end
  
  def contacts_to_phone
    all_campus_contacts = Contact.in_accounts([1,2,3])
    #tagged_to_ignore = Contact.tagged_with('ignore-myc13')
    #in_bsg = Contact.includes(:contact_groups).where('contact_groups.category = "BSG"')
    
    to_phone = all_campus_contacts - self.contacts #- tagged_to_ignore - in_bsg
  end

  private
  
  # Make sure at least one user has been selected if the campaign is being shared.
  #----------------------------------------------------------------------------
  def users_for_shared_access
    errors.add(:access, :share_campaign) if self[:access] == "Shared" && !self.permissions.any?
  end
  
  def nullify_blank_category
    self.category = nil if self.category.blank?
  end

end