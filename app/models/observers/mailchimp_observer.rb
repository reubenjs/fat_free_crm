#include NetworkHelper
class MailchimpObserver < ActiveRecord::Observer
  observe :contact

  def after_create(contact) 
    if contact.has_mailchimp_subscription?
      Delayed::Job.enqueue AddOrUpdateChimp.new(contact, contact.cf_weekly_emails.reject(&:blank?))
    end
  end

  def after_update(contact)
    if (contact.changes.keys & %w(cf_weekly_emails email first_name last_name cf_gender)).any?
      if contact.cf_weekly_emails.reject(&:blank?).empty?
        Delayed::Job.enqueue DeleteChimpByEmail.new(contact.email_was)
      else
        mailchimp_lists(contact)
      end
    end
  end
  
  def after_destroy(contact)
    
    Delayed::Job.enqueue DeleteChimpByEmail.new(contact.email)
    
  end

  private

  def mailchimp_lists(contact)
    
    # email_was is passed to add_or_update_chimp as a key to search in mailchimp lists. Therefore
    # update code needs to know what the email address was to find the contact in mailchimp lists.
    #
    # The two situations where we don't want to use previous email address are:
    # 
    # 1) previous email was blank (this contact wouldn't be on any mailchimp lists - it's invalid)
    # 2) contact was previously not subscribed to any lists, so no need to search by old email address
    #
    # the search key should probably be changed to a uid stored as an attribute of the contact
     
    email_was = contact.email_changed? ? contact.email_was : nil
    email_was = nil if contact.email_was.blank? || contact.cf_weekly_emails_was.reject(&:empty?).blank?
    
    Delayed::Job.enqueue AddOrUpdateChimp.new(contact, contact.cf_weekly_emails.reject(&:blank?), email_was)
    
  end
  
end