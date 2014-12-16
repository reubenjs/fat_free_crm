class ConferenceEmailJob < Struct.new(:registration_id, :subject, :from_name, :from_email, :email_body, :send_invoices, :bcc_email)
  def perform
    if Setting.mandrill[:enabled]  
      registration = Registration.find(registration_id)
    
      mandrill = Mailchimp::Mandrill.new(Setting.mandrill[:api_key])
      
      attached_array = [] 
      pdf = nil
      
      if send_invoices && registration.saasu_uid.present?
        
        retries = 3;
        begin
          Delayed::Worker.logger.add(Logger::INFO, "ConferenceEmailJob: getting pdf for #{registration.contact.name}")
          response = Saasu::Invoice.get_pdf(registration.saasu_uid, Setting.conference[:email_template])
          if response.errors.nil?
            pdf = response.pdf
          else
            pdf = nil
          end
        rescue Exception => e
            Delayed::Worker.logger.add(Logger::INFO, "WARN-ConferenceEmailJob: getting pdf for #{registration.contact.name} failed")
            Delayed::Worker.logger.add(Logger::INFO, "retrying")
            retries -= 1
            retry if retries > 0
            raise e if retries <= 0
        end
        
        unless pdf.nil?          
          attached_file = Base64.encode64(pdf)
          attached_array = [{ 
            :type => 'application/pdf', 
            :name => "#{registration.event.name.parameterize("_")}_#{registration.contact.name.parameterize("_")}.pdf", 
            :content => attached_file
          }]
        end
      end
      
      if pdf.nil? && send_invoices
        # notify admin if invoice not found. This is just a warning as people who get full discount will
        # not have an invoice
        UserMailer.delay.saasu_registration_error(registration.contact, "[WARN: pdf/invoice not found] for #{registration.contact.name}")
      end
      
      retries = 3 
      begin        
        Delayed::Worker.logger.add(Logger::INFO, "ConferenceEmailJob: emailing #{registration.contact.name}")            
        response = mandrill.messages_send_template({
          :template_name => "conference-plain",
          :template_content => [:name => "body_content", :content => email_body],
          :message => {
            :subject => subject,
            :from_name => from_name,
            :from_email => from_email,
            :to => email_recipients(registration.contact.email, registration.contact.name, bcc_email),
            :global_merge_vars => [{:name => "fname", :content => registration.contact.first_name}],
            :attachments => attached_array
          }
        })
      rescue Exception => e
          Delayed::Worker.logger.add(Logger::INFO, "WARN-ConferenceEmailJob: emailing #{registration.contact.name} failed")
          Delayed::Worker.logger.add(Logger::INFO, "retrying")
          retries -= 1
          retry if retries > 0
          raise e if retries <= 0
      end
    end
  end
  
  def email_recipients(to_email, to_name, bcc)
    recipients = [{:email => to_email, :name => to_name, :type => "to"}]
    recipients << {:email => bcc_email, :type => "bcc"} if !bcc.blank?
    recipients
  end
  
end

