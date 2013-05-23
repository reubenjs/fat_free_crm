class ConferenceEmailJob < Struct.new(:event_id, :subject, :from_name, :from_email, :email_body, :send_invoices)
  def perform
    if Setting.mandrill[:enabled]  
      event = Event.find(event_id)
    
      mandrill = Mailchimp::Mandrill.new(Setting.mandrill[:api_key])
      
      event.registrations.each do |registration|
        
        if send_invoices && registration.saasu_uid.present?          
          attached_file = Base64.encode64(Saasu::Invoice.get_pdf(registration.saasu_uid, Setting.conference[:email_template]))
          attached_array = [{ 
            :type => 'application/pdf', 
            :name => "#{registration.event.name.parameterize("_")}_#{registration.contact.name.parameterize("_")}.pdf", 
            :content => attached_file
          }]
        else
          attached_array = []
        end
                            
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
        
      end
    end
  end
end

