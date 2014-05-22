xml.Worksheet 'ss:Name' => (@event.name + " contact list") do
  xml.Table do
    unless @event.contacts.empty?
      # Header.
      xml.Row do
        heads = ["BSG",
                 "Registered?",
                 I18n.t('first_name'),
                 I18n.t('last_name')]
        
        heads.each do |head|
          xml.Cell do
            xml.Data head,
                     'ss:Type' => 'String'
          end
        end
      end
      
      contact_groups = ContactGroup.where(:category => :bsg, :inactive => false)
      registered = @event.contacts.collect(&:id)
      
      contact_groups.each do |contact_group|        
        # Contact rows.
        contact_group.contacts.each do |contact|
          xml.Row do
            data    = [contact_group.name, 
                       registered.include?(contact.id) ? "Yes" : "No",
                       contact.first_name,
                       contact.last_name]
        
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
end
