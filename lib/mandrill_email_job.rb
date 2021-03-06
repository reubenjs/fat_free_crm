class MandrillEmailJob < Struct.new(:mandrill_email_id)
  def perform
    if Setting.mandrill[:enabled]  
      mandrill_mail = MandrillEmail.find(mandrill_email_id)
    
      mandrill = Mailchimp::Mandrill.new(Setting.mandrill[:api_key])
      recipients = []

      case mandrill_mail.mailing_list 
      when "terrace_times"
        recipients = Contact.where('cf_supporter_emails LIKE (?)', "%TT Email%")
      when "prayer_points"
        recipients = Contact.where('cf_supporter_emails LIKE (?)', "%Prayer Points%")
      when "both"
        recipients = Contact.where('cf_supporter_emails LIKE (?) OR cf_supporter_emails LIKE (?)', "%TT Email%", "%Prayer Points%")
      end
      
      unless recipients.nil?
        recipients_list = recipients.collect{|r| {:email => r.email, :name => r.full_name}}
        if mandrill_mail.attached_files.exists?
          attached_file_name = mandrill_mail.attached_files.first.attached_file_file_name
          attached_file = Base64.encode64(open(mandrill_mail.attached_files.first.attached_file.path, &:read))
          attached_array = [{ :type => 'application/pdf', 
                              :name => attached_file_name, 
                              :content => attached_file}]
        else
          attached_array = []
        end
        
        
        response = mandrill.messages_send_template({
                             :template_name => mandrill_mail.template,
                             :template_content => [:name => "body_content", :content => mandrill_mail.message_body], #.gsub(/(?:\n\r?|\r\n?)/, '<br>')],
                             :message => {
                               :subject => mandrill_mail.message_subject,
                               :from_name => mandrill_mail.from_name,
                               :from_email => mandrill_mail.from_address,
                               :to => recipients_list,
                               :attachments => attached_array
                             }
                            })
        #logger.info("RESPONSE >> " + response)
        #response = "some response"
        mandrill_mail.update_attributes(:sent_at => Time.now, :response => response, :delayed_job_id => nil)
        mandrill_mail.save
      end
    end
  end
end

