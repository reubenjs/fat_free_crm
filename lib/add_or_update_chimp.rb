class AddOrUpdateChimp < Struct.new(:contact, :lists, :email_was)
  
  def perform
    list_id = Setting.mailchimp["list_id"]
    list_key = Setting.mailchimp["api_key"]

    mc_api = Mailchimp::API.new(list_key, :throws_exceptions => true)
    
    original_email = email_was.nil? ? contact.email : email_was

    member_search = mc_api.list_member_info({:id => list_id, :email_address => original_email})
    new_chimp_contact = (member_search["success"] == 0)

    c_hash = {
      :id => list_id,
      :email_address => original_email,
      :merge_vars => 
        Hash.new.tap do |merge_hash|
          #merge_hash["EMAIL"] = original_email
          merge_hash["EMAIL"] = contact.email
          merge_hash["GROUPINGS"] = [{:name => "Subscribe to these campus newsletters", :groups => lists.join(", ")}] unless (lists == [])
          merge_hash["OPTIN_IP"] = Setting.network[:public_ip] if new_chimp_contact # or public_ip... => see network_helper.rb
          merge_hash["OPTIN_TIME"] = Time.now if new_chimp_contact
          merge_hash["FNAME"] = contact.first_name
          merge_hash["LNAME"] = contact.last_name
          merge_hash["GENDER"] = contact.cf_gender
        end 
    }
    
    if new_chimp_contact
      c_hash[:double_optin] = false
      r = mc_api.list_subscribe(c_hash)
      t = "Added"
    else
      c_hash[:email_address] = member_search["data"][0]["id"]
      r = mc_api.list_update_member(c_hash)
      t = "Updated"
    end
    Delayed::Worker.logger.add(Logger::INFO, "#{Time.now}: #{t} #{contact.first_name} #{contact.last_name} to interest groups #{lists.join(", ")}. Mailchimp responded: #{r}")
    
  end
  
end