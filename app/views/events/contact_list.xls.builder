xml.Worksheet 'ss:Name' => (@event.name + " contact list") do
  xml.Table do
    unless @event.contacts.empty?
      # Header.
      xml.Row do
        heads = [I18n.t('lead'),
                 I18n.t('job_title'),
                 I18n.t('name'),
                 I18n.t('first_name'),
                 I18n.t('last_name'),
                 I18n.t('preferred_name'),
                 I18n.t('email'),
                 I18n.t('alt_email'),
                 I18n.t('phone'),
                 I18n.t('mobile'),
                 I18n.t('date_created'),
                 I18n.t('date_updated'),
                 I18n.t('assigned_to'),
                 I18n.t('access'),
                 I18n.t('department'),
                 I18n.t('source'),
                 I18n.t('do_not_call'),
                 I18n.t('street1'),
                 I18n.t('street2'),
                 I18n.t('city'),
                 I18n.t('state'),
                 I18n.t('zipcode'),
                 I18n.t('country'),
                 I18n.t('address'),
                 "Transport required",
                 "Driver for",
                 "Can transport",
                 "First time",
                 "Part time",
                 "Breakfasts",
                 "Lunches",
                 "Dinners",
                 "Sleeps",
                 "Fee",
                 "Payment method",
                 "T Shirt ordered",
                 "T Shirt size ordered"]
        
        # Append custom field labels to header
        Contact.fields.each do |field|
          heads << field.label unless field.label == "Financial Status"
        end
        
        heads.each do |head|
          xml.Cell do
            xml.Data head,
                     'ss:Type' => 'String'
          end
        end
      end
      
      # Contact rows.
      @event.contacts.each do |contact|
        r = Registration.where(:event_id => @event.id, :contact_id => contact.id).first
        xml.Row do
          address = contact.business_address
          data    = [contact.lead.try(:name),
                     contact.title,
                     contact.name,
                     contact.first_name,
                     contact.last_name,
                     contact.preferred_name,
                     contact.email,
                     contact.alt_email,
                     contact.phone,
                     contact.mobile,
                     contact.created_at,
                     contact.updated_at,
                     contact.assignee.try(:name),
                     contact.access,
                     contact.department,
                     contact.source,
                     contact.do_not_call,
                     address.try(:street1),
                     address.try(:street2),
                     address.try(:city),
                     address.try(:state),
                     address.try(:zipcode),
                     address.try(:country),
                     address.try(:full_address),
                     r.transport_required,
                     r.driver_for,
                     r.can_transport,
                     r.first_time,
                     r.part_time,
                     r.breakfasts,
                     r.lunches,
                     r.dinners,
                     r.sleeps,
                     r.fee,
                     r.payment_method,
                     r.t_shirt_ordered,
                     r.t_shirt_size_ordered]
          
          # Append custom field values.
          Contact.fields.each do |field|
            data << contact.send(field.name) unless field.label == "Financial Status"
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
