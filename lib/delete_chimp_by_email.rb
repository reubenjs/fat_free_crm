class DeleteChimpByEmail < Struct.new(:contact_email)
  
  def perform
    list_id = Setting.mailchimp["list_id"]
    list_key = Setting.mailchimp["api_key"]

    mc_api = Mailchimp::API.new(list_key, :throws_exceptions => true)
    
    r = mc_api.list_unsubscribe({
      :id => list_id,
      :email_address => contact_email,
      :delete_member => true,
      :send_goodbye => false
    })
    Delayed::Worker.logger.add(Logger::INFO, "#{Time.now}: Deleted_by_email #{contact_email}. Mailchimp responded: #{r}")
  end
  
end