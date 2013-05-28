xml.Worksheet 'ss:Name' => (@event.name + " contact list") do
  xml.Table do
    unless @event.contacts.empty?
      # Header.
      xml.Row do
        heads = [I18n.t('name'),
                 I18n.t('first_name'),
                 I18n.t('last_name'),
                 I18n.t('email'),
                 I18n.t('alt_email'),
                 I18n.t('phone'),
                 I18n.t('mobile')
               ]
        
        # Append custom field labels to header
        Contact.fields.each do |field|
          heads << field.label
        end
        
        heads.each do |head|
          xml.Cell do
            xml.Data head,
                     'ss:Type' => 'String'
          end
        end
      end
      
      
      
      # Contact rows.
      @event.contacts_to_phone.each do |contact|
        xml.Row do
          address = contact.business_address
          data    = [contact.name,
                     contact.first_name,
                     contact.last_name,
                     contact.email,
                     contact.alt_email,
                     contact.phone,
                     contact.mobile]
          
          # Append custom field values.
          Contact.fields.each do |field|
            data << contact.send(field.name)
          end
          
          data.each do |value|
            xml.Cell do
              xml.Data value,
                       'ss:Type' => "#{value.respond_to?(:abs) ? 'Number' : 'String'}"
            end
          end
        end
      end
    end
  end
end
