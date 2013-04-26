xml.Worksheet 'ss:Name' => (@event.name + " contact list") do
  xml.Table do
    unless @event.contacts.empty?
      day_names = %w(Mon Tue Wed Thu Fri)
      # Header.
      xml.Row do
        ["Day","First Name","Last Name"].each do |head|
          xml.Cell do
            xml.Data head,
                     'ss:Type' => 'String'
          end
        end
      end
      
      # Contact rows.
      day_names.each do |day|
        @event.contacts_accommodated_on(day).each_with_index do |contact, i|
          xml.Row do
            d = (i==0 ? day : "")
            data    = [d, contact.first_name, contact.last_name]
          
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
end
