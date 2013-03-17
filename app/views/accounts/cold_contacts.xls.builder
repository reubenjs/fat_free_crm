xml.Worksheet 'ss:Name' => I18n.t(:tab_accounts) do
  xml.Table do
    unless @account.contacts.empty?
      # Header.
      xml.Row do
        heads = [I18n.t('name'),
                 I18n.t('email'),
                 I18n.t('mobile'),
                 "Last TBT",
                 "Last BSG",
                 "Neither"]
        
        heads.each do |head|
          xml.Cell do
            xml.Data head,
                     'ss:Type' => 'String'
          end
        end
      end
      
      # Account rows.
      @account.contacts.each do |contact|
        tbt = contact.last_attendance_at_event_category("bible_talk")
        bsg = contact.last_attendance_at_event_category("bsg")
        xml.Row do
          data    = [contact.name,
                     contact.email,
                     contact.mobile,
                     (!tbt.nil? && tbt > (Time.now - 4.weeks)) ? tbt.strftime("%d/%m") : "",
                     (!bsg.nil? && bsg > (Time.now - 4.weeks)) ? bsg.strftime("%d/%m") : "",
                     (tbt.nil? && bsg.nil?) ? "True" : "False"]
                     
          
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
