class RegistrationObserver < ActiveRecord::Observer
  observe :registration
  
  def after_create(registration) 
    if registration.fee.to_i > 0
      self.delay.add_saasu(registration) 
      registration.update_attributes(:saasu_uid => "delayed")
    end
  end
  
  def after_update(registration)
    if (registration.saasu_uid.blank? && registration.fee.to_i > 0)
      self.delay.add_saasu(registration) 
      registration.update_attributes(:saasu_uid => "delayed")
    end
  end
  
  def after_destroy(registration)
    #self.delay.delete_saasu(registration.saasu_uid) if registration.saasu_uid.present?
  end

  private

  def add_saasu(registration)
    i = Saasu::Invoice.new
    i.uid = "0"
    i.transaction_type = "S"
    i.date = Time.now.strftime("%Y-%m-%d")
    i.layout = "S"
    i.status = "I"
    i.invoice_number = "&lt;Auto Number&gt;"
    i.invoice_type = "Sale Invoice"
    i.tags = "myc"
    i.summary = "MYC 2013 Registration"
    i.notes = "Registration added by Mojo for #{registration.contact.full_name}"
    
    if registration.contact.present? && !registration.contact.saasu_uid.blank?
      i.contact_uid = registration.contact.saasu_uid
    end
    
    fee = Saasu::ServiceInvoiceItem.new
    fee.description = "MYC registration fee"
    fee.account_uid = Setting.saasu[:myc_income_account]
    fee.total_amount_incl_tax = registration.fee.to_i - registration.donate_amount.to_i
    
    i.invoice_items = [fee]
    
    if registration.donate_amount.to_i > 0
      donation = Saasu::ServiceInvoiceItem.new
      donation.description = "Donation"
      donation.account_uid = Setting.saasu[:donation_account]
      donation.total_amount_incl_tax = registration.donate_amount.to_i
      
      i.invoice_items << donation
    end

    tt = Saasu::TradingTerms.new
    tt.type = 1
    tt.interval = 0
    tt.interval_type = 0
    
    i.trading_terms = tt
    
    if registration.payment_method == "PayPal"
      qp = Saasu::QuickPayment.new
      qp.date_paid = Time.now.strftime("%Y-%m-%d")
      qp.banked_to_account_uid = Setting.saasu[:paypal_account]
      qp.amount = registration.fee.to_i
      qp.summary = "auto entered: paypal payment"
      
      i.quick_payment = [qp]
    end
    
    response = Saasu::Invoice.insert(i)
    
    if response.errors.nil?
      registration.saasu_uid = response.inserted_entity_uid
      registration.save!
      Delayed::Worker.logger.add(Logger::INFO, "Added invoice for #{registration.contact.full_name} to saasu")
    else
      Delayed::Worker.logger.add(Logger::INFO, "Error adding invoice for #{registration.contact.full_name} to saasu. #{response.errors}")
    end
  end
  
  def update_saasu(registration, updated_uid)

  end
  
  def delete_saasu(saasu_uid)

  end
  
end