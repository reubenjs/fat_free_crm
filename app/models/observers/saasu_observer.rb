class SaasuObserver < ActiveRecord::Observer
  observe :contact
  
  def before_create(contact)
    #contact.saasu_uid = "locked"
    add_saasu(contact) if !in_excluded_account?(contact)
  end
  
  def before_update(contact)
    if contact.saasu_uid != "locked"
      if contact.saasu_uid.present? && contact.account.present? && in_excluded_account?(contact)
        # moved into an excluded account - time to delete from saasu
        Delayed::Worker.logger.add(Logger::INFO, "[moved] Requesting that #{contact.full_name} be deleted from saasu (uid = #{contact.saasu_uid})")
        delete_saasu(contact.saasu_uid)
        contact.saasu_uid = nil
      
      elsif !in_excluded_account?(contact)
        # saasu_uid.nil? prevents a "locked" contact from being added twice
        # also triggers when a contacts is moved back into a non-excluded account
        if (contact.saasu_uid.nil? ||
            contact.email_changed? || 
            contact.first_name_changed? || 
            contact.last_name_changed? || 
            contact.mobile_changed? || 
            contact.phone_changed?)
        
          if contact.saasu_uid.nil?
            add_saasu(contact)
          else
            update_saasu(contact)
          end
        end
      end
    end
  end
  
  def after_destroy(contact)
    if contact.saasu_uid.present?
      Delayed::Worker.logger.add(Logger::INFO, "[deleted] Requesting that #{contact.full_name} be deleted from saasu (uid = #{contact.saasu_uid})")
      self.delay.delete_saasu(contact.saasu_uid) 
    end
  end

  private
  
  def in_excluded_account?(contact)
    excluded = Setting.excluded_folders
    excluded_accounts = Account.where('name IN (?)', excluded).collect{|a| a.id}
    
    !Contact.includes(:account).where('contacts.id = ? AND accounts.id IN (?)', contact.id, excluded_accounts).empty?
  end

  def add_saasu(c)
    sc = Saasu::Contact.new
    sc.given_name = c.first_name
    sc.family_name = c.last_name
    sc.email_address = c.email
    sc.email = c.email
    sc.mobile_phone = c.mobile
    sc.main_phone = c.mobile
    sc.home_phone = c.phone
    response = Saasu::Contact.insert(sc)
    
    if response.errors.nil?
      c.saasu_uid = response.inserted_entity_uid
      Delayed::Worker.logger.add(Logger::INFO, "Added #{c.full_name} to saasu")
    else
      Delayed::Worker.logger.add(Logger::INFO, "Error adding #{c.full_name} to saasu. #{response.errors}")
      UserMailer.saasu_registration_error(c, "[add_saasu] #{response.errors[0].message}").deliver
    end
  end
  
  def update_saasu(c)
    
    # check that contact (still) exists in saasu, if not add.
    response = Saasu::Contact.find(c.saasu_uid)
    
    if response.errors.present? && response.errors.first.type == "RecordNotFoundException"
      add_saasu(c)
    elsif response.last_updated_uid
      # contact found ...update
      sc = Saasu::Contact.new
      sc.given_name = c.first_name
      sc.family_name = c.last_name
      sc.email_address = c.email
      sc.email = c.email
      sc.mobile_phone = c.mobile
      sc.main_phone = c.mobile
      sc.home_phone = c.phone
      sc.uid = c.saasu_uid
      sc.last_updated_uid = response.last_updated_uid
    
      response = Saasu::Contact.update(sc)
    
      if response.errors.nil?
        Delayed::Worker.logger.add(Logger::INFO, "Updated #{c.full_name} to saasu")
      else
        Delayed::Worker.logger.add(Logger::INFO, "Error updating #{c.full_name} to saasu. #{response.errors}")
        UserMailer.saasu_registration_error(c, "[update_saasu] #{response.errors[0].message}").deliver
      end
    else
      # unhandled error. notify admin
      UserMailer.saasu_registration_error(c, "[after_update] #{response.errors[0].message}").deliver
    end
  end
  
  def delete_saasu(saasu_uid)
    response = Saasu::Contact.delete(saasu_uid)
    
    if response.errors.nil?
      Delayed::Worker.logger.add(Logger::INFO, "Deleted contact with saasu_uid #{saasu_uid}")
    else
      Delayed::Worker.logger.add(Logger::INFO, "Error deleting contact with saasu_uid #{saasu_uid}. #{response.errors}")
      UserMailer.saasu_registration_error(c, "[delete_saasu] #{response.errors[0].message}").deliver
    end
  end
  
end