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
    
    if registration.payment_method != "PayPal"
      discount = Saasu::ServiceInvoiceItem.new
      discount.description = "Online payment discount (if paid before 19th July)"
      discount.account_uid = Setting.saasu[:myc_income_account]
      discount.total_amount_incl_tax = -5
      
      i.invoice_items << discount
    end
    
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
    
    email = Saasu::EmailMessage.new
    email.to = registration.contact.email
    email.bcc = Setting.conference[:bcc]
    email.from = Setting.conference[:email_address]
    email.subject = Setting.conference[:email_subject]
    email.body = "Dear #{registration.contact.first_name},\r\n\r\n
      Please find your invoice/receipt attached. If you have not already paid, the invoice contains a link to pay online that you can use at any time.\r\n\r\n
      Pay online before the 19th of July to receive a $5 early-bird discount.\r\n\r\n
      In Christ,\r\n\r\n
      The MYC Team"
    
    if registration.payment_method == "PayPal"
      qp = Saasu::QuickPayment.new
      qp.date_paid = Time.now.strftime("%Y-%m-%d")
      qp.banked_to_account_uid = Setting.saasu[:paypal_account]
      qp.amount = registration.fee.to_i
      qp.summary = "auto entered: paypal payment"
      
      i.quick_payment = [qp]
    end
    
    response = Saasu::Invoice.insert_and_email(i, email, Setting.conference[:email_template].to_i)
    
    if response.errors.nil?
      registration.saasu_uid = response.inserted_entity_uid
      registration.save!
      Delayed::Worker.logger.add(Logger::INFO, "Added invoice for #{registration.contact.full_name} to saasu")
    else
      Delayed::Worker.logger.add(Logger::INFO, "Error adding invoice for #{registration.contact.full_name} to saasu. #{response.errors}")
      UserMailer.delay.saasu_registration_error(registration.contact, response.errors[0].message)
    end
  end
  
  def update_saasu(registration, updated_uid)

  end
  
  def delete_saasu(saasu_uid)

  end
  
end