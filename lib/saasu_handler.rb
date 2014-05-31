module SaasuHandler
  def update_saasu(registration, send_invoice=false)
    i = Saasu::Invoice.find(registration.saasu_uid)

    if i.errors.present? && rnf_error(i.errors)
      #either this registration has no linked invoice (saasu_uid = nil)
      #or invoice doesn't exist in saasu anymore...add
      add_saasu(registration)
    else
      already_paid = 0
  
      if i.payments.present?
        i.payments.each do |p| 
          already_paid += p.amount
        end
      end
  
      if (already_paid > registration.fee.to_i)
        #This would result in an overpayment error, don't update saasu invoice - it will have to be modified manually
        Delayed::Worker.logger.add(
          Logger::INFO, 
          "Not updating invoice for #{registration.contact.full_name} to saasu as it would result in an overpayment"
          )
        UserMailer.delay.saasu_registration_error(registration.contact, "Change to registration not updated to Saasu as it would result in an overpayment. Manual entry required")
      else
        if (registration.t_shirt_ordered_changed? || 
            registration.donate_amount_changed? || 
            registration.fee_changed?)
    
          i.invoice_items = calculate_invoice_items(registration)
        end
        if registration.payment_method_was == "Cash" && registration.payment_method == "PayPal"
          i.quick_payment = calculate_payment(registration)
        end
    
        if send_invoice
          response = Saasu::Invoice.update_and_email(i, generate_email(registration), Setting.conference[:email_template].to_i)
        else
          response = Saasu::Invoice.update(i)
        end

        if response.errors.nil?
          Delayed::Worker.logger.add(Logger::INFO, "Updated invoice for #{registration.contact.full_name} to saasu")
        else
          Delayed::Worker.logger.add(Logger::INFO, "Error updating invoice for #{registration.contact.full_name} to saasu. #{response.errors}")
          UserMailer.delay.saasu_registration_error(registration.contact, response.errors[0].message)
        end
    
      end
    end
  end

  def add_saasu(registration)
    i = Saasu::Invoice.new
    i.uid = "0"
    i.transaction_type = "S"
    i.date = Time.now.strftime("%Y-%m-%d")
    i.layout = "S"
    i.status = "I"
    i.invoice_number = "&lt;Auto Number&gt;"
    i.invoice_type = "Sale Invoice"
    i.tags = "myc14"
    i.summary = "MYC 2014 Registration"
    i.notes = "Registration added by Mojo for #{registration.contact.full_name}"
  
    if registration.contact.present?
      i.contact_uid = find_or_add_to_saasu(registration.contact)
    end
  
    i.invoice_items = calculate_invoice_items(registration)

    tt = Saasu::TradingTerms.new
    tt.type = 1
    tt.interval = 0
    tt.interval_type = 0
  
    i.trading_terms = tt
  
    if registration.payment_method == "PayPal"
      i.quick_payment = calculate_payment(registration)
    end
  
    response = Saasu::Invoice.insert_and_email(i, generate_email(registration), Setting.conference[:email_template].to_i)
  
    if response.errors.nil?
      registration.saasu_uid = response.inserted_entity_uid
      Delayed::Worker.logger.add(Logger::INFO, "Added invoice for #{registration.contact.full_name} to saasu")
    else
      registration.saasu_uid = nil
      Delayed::Worker.logger.add(Logger::INFO, "Error adding invoice for #{registration.contact.full_name} to saasu. #{response.errors}")
      UserMailer.delay.saasu_registration_error(registration.contact, response.errors[0].message)
    end
    #registration.save
  end
  
  def generate_email(registration)
    email = Saasu::EmailMessage.new
    if Rails.env.production?
      email.to = registration.contact.email
      email.bcc = Setting.conference[:bcc]
    else
      email.to = Setting.conference[:bcc]
    end
    email.from = Setting.conference[:email_address]
    email.subject = Setting.conference[:email_subject]
    email.body = "Dear #{registration.contact.first_name},\r\n\r\n
      Please find your invoice/receipt attached. If you have not already paid, the invoice contains a link to pay online that you can use at any time.\r\n\r\n
      Thank you,\r\n\r\n
      The MYC Team"
    
    email
  end

  def calculate_payment(registration)
    qp = Saasu::QuickPayment.new
    qp.date_paid = Time.now.strftime("%Y-%m-%d")
    qp.banked_to_account_uid = Setting.saasu[:paypal_account]
    qp.amount = registration.fee.to_i
    qp.summary = "auto entered: paypal payment"
  
    [qp]
  end

  def calculate_invoice_items(registration)
  
    invoice_items = []
  
    fee = Saasu::ServiceInvoiceItem.new
    fee.description = "MYC registration fee"
    fee.account_uid = Setting.saasu[:myc_income_account]
    fee.total_amount_incl_tax = registration.fee.to_i - registration.donate_amount.to_i - (registration.t_shirt_ordered.to_i * 35)
  
    invoice_items << fee
  
    if registration.payment_method != "PayPal"
      discount = Saasu::ServiceInvoiceItem.new
      discount.description = "Online payment discount (if paid before 20th June)"
      discount.account_uid = Setting.saasu[:myc_income_account]
      discount.total_amount_incl_tax = -10
    
      invoice_items << discount
    end
  
    if registration.t_shirt_ordered.to_i  > 0
      tshirt = Saasu::ServiceInvoiceItem.new
      tshirt.description = "Jesus Week jumper"
      tshirt.account_uid = Setting.saasu[:jw_jumper_account]
      tshirt.total_amount_incl_tax = (registration.t_shirt_ordered.to_i * 35)

      invoice_items << tshirt
    end
  
    if registration.donate_amount.to_i > 0
      donation = Saasu::ServiceInvoiceItem.new
      donation.description = "Donation"
      donation.account_uid = Setting.saasu[:myc_donation_account]
      donation.total_amount_incl_tax = registration.donate_amount.to_i
    
      invoice_items << donation
    end
  
    invoice_items
  
  end

  def delete_saasu(saasu_uid)

  end

  def find_or_add_to_saasu(contact)
    if contact.saasu_uid.blank?
      add_to_saasu(contact)
    else
      response = Saasu::Contact.find(contact.saasu_uid)
    
      if response.errors.present? && response.errors.first.type == "RecordNotFoundException"
        add_to_saasu(contact)
      end
    end
  
    contact.saasu_uid
  
  end

  def add_to_saasu(contact)
    sc = Saasu::Contact.new
    sc.given_name = contact.first_name
    sc.family_name = contact.last_name
    sc.email_address = contact.email
    sc.email = contact.email
    sc.mobile_phone = contact.mobile
    sc.main_phone = contact.mobile
    sc.home_phone = contact.phone
    response = Saasu::Contact.insert(sc)
  
    if response.errors.nil?
      contact.saasu_uid = response.inserted_entity_uid
      contact.save!
      Delayed::Worker.logger.add(Logger::INFO, "Added #{contact.full_name} to saasu")
    else
      Delayed::Worker.logger.add(Logger::INFO, "Error adding #{contact.full_name} to saasu. #{response.errors}")
      UserMailer.saasu_registration_error(contact, "[add_saasu] #{response.errors[0].message}").deliver
    end
  end
    
  def rnf_error(errors)
    rnf = false
    errors.each do |e|
      rnf = true if e.type == "RecordNotFoundException"
    end
    rnf
  end
end

