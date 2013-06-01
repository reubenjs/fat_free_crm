class ConferenceEmailJob < Struct.new(:registration_id, :subject, :from_name, :from_email, :email_body, :send_invoices)
  def perform
    if Setting.mandrill[:enabled]  
      registration = Registration.find(registration_id)
    
      mandrill = Mailchimp::Mandrill.new(Setting.mandrill[:api_key])
        
      if send_invoices && registration.saasu_uid.present?
        
        retries = 3;
        begin
          puts "ConferenceEmailJob: getting pdf for #{registration.contact.name}"
          pdf = Saasu::Invoice.get_pdf(registration.saasu_uid, Setting.conference[:email_template])
        rescue Exception => e
            puts "WARN-ConferenceEmailJob: getting pdf for #{registration.contact.name} failed"
            puts "retrying"
            retries -= 1
            retry if retries > 0
            raise e if retries <= 0
        end          
        attached_file = Base64.encode64(pdf)
        attached_array = [{ 
          :type => 'application/pdf', 
          :name => "#{registration.event.name.parameterize("_")}_#{registration.contact.name.parameterize("_")}.pdf", 
          :content => attached_file
        }]
      else
        attached_array = []
      end
      
      retries = 3 
      begin        
        puts "ConferenceEmailJob: emailing #{registration.contact.name}"            
        response = mandrill.messages_send_template({
          :template_name => "conference-plain",
          :template_content => [:name => "body_content", :content => email_body],
          :message => {
            :subject => subject,
            :from_name => from_name,
            :from_email => from_email,
            :to => [{:email => registration.contact.email, :name => registration.contact.name}],
            :global_merge_vars => [{:name => "fname", :content => registration.contact.first_name}],
            :attachments => attached_array
          }
        })
      rescue Exception => e
          puts "WARN-ConferenceEmailJob: emailing #{registration.contact.name} failed"
          puts "retrying"
          retries -= 1
          retry if retries > 0
          raise e if retries <= 0
      end
    end
  end
end

