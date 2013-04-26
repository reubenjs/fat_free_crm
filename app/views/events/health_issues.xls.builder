xml.Worksheet 'ss:Name' => (@event.name + " contact list") do
  xml.Table do
    unless @event.contacts.empty?
      # Header
      xml.Row do
        headings = ["First Name", "Last Name", "Dietary/Health Issue Details", "Emergency Contact", "Emergency Contact Relationship", "Emergency Contact Number"]
        
        headings.each do |head|
          xml.Cell do
            xml.Data head, 'ss:Type' => 'String'
          end
        end
      end
      
      # Contact rows.
      contacts = @event.contacts.where(:cf_has_dietary_or_health_issues => true)
      
      contacts.each do |contact|
        xml.Row do
          data = [contact.first_name, 
                  contact.last_name, 
                  contact.cf_dietary_health_issue_details, 
                  contact.cf_emergency_contact,
                  contact.cf_emergency_contact_relationship,
                  contact.cf_emergency_contact_number]
      
          data.each do |value|
            xml.Cell do
              xml.Data value,
                       'ss:Type' => 'String'
            end
          end
        end
      end
    end
  end
end
