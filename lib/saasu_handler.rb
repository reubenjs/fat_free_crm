module SaasuHandler
  def update_saasu(registration, options={})# send_invoice=false, end_of_earlybird=false)
    default_options = {
      :send_invoice => false,
      :end_of_earlybird => false,
    }
    
    options = options.reverse_merge(default_options)
    
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
            registration.fee_changed? ||
            registration.discount_allowed_changed?)
    
          i.invoice_items = calculate_invoice_items(registration)
        end
        if registration.payment_method_was == "Cash" && registration.payment_method == "Online"
          i.quick_payment = calculate_payment(registration)
        end
    
        response = Saasu::Invoice.update(i)

        if response.errors.nil?
          Delayed::Worker.logger.add(Logger::INFO, "Updated invoice for #{registration.contact.full_name} to saasu")
          
          generate_email(
            registration, 
            :send_invoice => options[:send_invoice], 
            :earlybird => options[:end_of_earlybird]
          )
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
    i.tags = registration.event.saasu_tags
    i.summary = "#{registration.event.name} Registration"
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
  
    if registration.payment_method == "Online"
      i.quick_payment = calculate_payment(registration)
    end
  
    response = Saasu::Invoice.insert(i)
  
    if response.errors.nil?
      registration.saasu_uid = response.inserted_entity_uid
      Delayed::Worker.logger.add(Logger::INFO, "Added invoice for #{registration.contact.full_name} to saasu")
    else
      registration.saasu_uid = nil
      Delayed::Worker.logger.add(Logger::INFO, "Error adding invoice for #{registration.contact.full_name} to saasu. #{response.errors}")
      UserMailer.delay.saasu_registration_error(registration.contact, response.errors[0].message)
    end
    
    registration.save
    
    generate_email(registration, :send_invoice => true)
    
  end
  
  def generate_email(registration, options={})
    default_options = {
      :earlybird => false,
      :send_invoice => false
    }
    
    options = options.reverse_merge(default_options)
    
    type = options[:earlybird] ? "end_earlybird" : "confirmation"
    
    # Send confirmation email
    # ------------------------
    Delayed::Job.enqueue(ConferenceEmailJob.new(
      registration.id, 
      registration.event["#{type}_email_subject"], 
      registration.event["#{type}_email_from_name"], 
      registration.event["#{type}_email_from_address"], 
      parse_email_body(registration, registration.event["#{type}_email"]), 
      options[:send_invoice]
    ))
  end
  
  def parse_email_body(registration, text)
    allowed_fields = {
      :contact => %w(first_name preferred_name last_name cf_gender cf_campus cf_faculty cf_course_1 cf_expected_grad_year cf_church_affiliation cf_denomination email mobile cf_dietary_health_issue_details cf_emergency_contact cf_emergency_contact_relationship cf_emergency_contact_number school),
      
      :registration => %w(transport_required driver_for can_transport first_time part_time breakfasts lunches dinners sleeps donate_amount fee need_financial_assistance payment_method t_shirt_ordered t_shirt_size_ordered international_student requires_sleeping bag payment_link)
    }
    
    to_replace = text.scan( /\[([^\]]*)\]/)
    to_replace.each do |merge_var|
      split_merge_var = merge_var[0].split(".")
      if split_merge_var.length == 2
        merge_model = split_merge_var[0]
        merge_field = split_merge_var[1]

        if (allowed_fields[merge_model.to_sym] &&
          allowed_fields[merge_model.to_sym].include?(merge_field))
          
          record = merge_model == "contact" ? registration.contact : registration.instance_eval { attributes.merge("payment_link" => payment_link)}
          replacement = record[merge_field]
          
          text.gsub!("[#{merge_model}.#{merge_field}]", replacement.nil? ? "" : replacement.to_s) 
        end
      end
    end

    text
    
  end

  def calculate_payment(registration)
    qp = Saasu::QuickPayment.new
    qp.date_paid = Time.now.strftime("%Y-%m-%d")
    qp.banked_to_account_uid = Setting.saasu[:paypal_account]
    qp.amount = registration.fee.to_i
    qp.summary = "auto entered: online payment #{registration.contact.full_name}"
  
    [qp]
  end

  def calculate_invoice_items(registration)
  
    invoice_items = []
  
    fee = Saasu::ServiceInvoiceItem.new
    fee.description = "#{registration.event.name} registration fee"
    fee.account_uid = Setting.saasu[:ccamp_income_account]
    fee.total_amount_incl_tax = registration.fee.to_i - registration.donate_amount.to_i - (registration.t_shirt_ordered.to_i * 20)
  
    invoice_items << fee

    if registration.payment_method != "Online" && registration.discount_allowed
      discount = Saasu::ServiceInvoiceItem.new
      discount.description = "Online payment discount (if paid before 20th June)"
      discount.account_uid = Setting.saasu[:myc_income_account]
      discount.total_amount_incl_tax = -10
    
      invoice_items << discount
    end
  
    if registration.t_shirt_ordered.to_i  > 0
      tshirt = Saasu::ServiceInvoiceItem.new
      tshirt.description = "ES T-Shirt"
      #tshirt.account_uid = Setting.saasu[:jw_jumper_account]
      tshirt.account_uid = Setting.saasu[:tshirt_account]
      tshirt.total_amount_incl_tax = (registration.t_shirt_ordered.to_i * 20)

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

