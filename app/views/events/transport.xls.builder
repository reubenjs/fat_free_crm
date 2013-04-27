xml.Worksheet 'ss:Name' => (@event.name + " contact list") do
  xml.Table do
    unless @event.contacts.empty?
      # Header
      xml.Row do
        headings = ["First Name", "Last Name", "Email", "Mobile", "Transport Required", "Can provide trasnport for", "Driver for"]
        
        headings.each do |head|
          xml.Cell do
            xml.Data head, 'ss:Type' => 'String'
          end
        end
      end
      
      # Contact rows.
      registrations = @event.registrations
      
      registrations.each do |registration|
        xml.Row do
          data = [registration.contact.first_name, 
                  registration.contact.last_name, 
                  registration.contact.email,
                  registration.contact.mobile,
                  registration.transport_required, 
                  registration.can_transport,
                  registration.driver_for
                  ]
      
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
