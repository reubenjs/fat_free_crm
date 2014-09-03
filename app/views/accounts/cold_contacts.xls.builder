registerables = Event.where(:inactive => false, :has_registrations => true)
registerables_heads = registerables.map(&:name)
  
xml.Styles do
  xml.Style 'ss:ID' => "Default", 'ss:Name' => "Normal" do
    xml.Alignment 'ss:Vertical' => "Bottom"
  end
  xml.Style 'ss:ID' => "s21" do
    xml.Alignment 'ss:Horizontal' => "Center"
  end
  xml.Style 'ss:ID' => "s24" do
    xml.Font 'ss:FontName' => "Verdana", 'ss:Bold' => 1
  end
  xml.Style 'ss:ID' => "s25" do
    xml.Interior 'ss:Color' => "#FCF305", 'ss:Pattern' => "Solid"
  end
  xml.Style 'ss:ID' => "s26" do
    xml.Interior 'ss:Color' => "#1FB714", 'ss:Pattern' => "Solid"
    xml.Font 'ss:FontName' => "Verdana", 'ss:Bold' => 1
  end
  xml.Style 'ss:ID' => "s27" do
    xml.Borders do
      xml.Border 'ss:Position' => "Bottom", 'ss:LineStyle' => "Continuous", 'ss:Weight' => 2
    end
    xml.Font 'ss:FontName' => "Verdana", 'ss:Bold' => 1
  end
  xml.Style 'ss:ID' => "s28" do
    xml.Borders do
      xml.Border 'ss:Position' => "Left", 'ss:LineStyle' => "Continuous", 'ss:Weight' => 1
    end
    xml.Interior 'ss:Color' => "#FCF305", 'ss:Pattern' => "Solid"
    xml.Font 'ss:FontName' => "Verdana", 'ss:Bold' => 1
  end
  xml.Style 'ss:ID' => "s29" do
    xml.Borders do
      xml.Border 'ss:Position' => "Bottom", 'ss:LineStyle' => "Continuous", 'ss:Weight' => 2
      xml.Border 'ss:Position' => "Left", 'ss:LineStyle' => "Continuous", 'ss:Weight' => 1
    end
    xml.Font 'ss:FontName' => "Verdana", 'ss:Bold' => 1
  end
  xml.Style 'ss:ID' => "s30" do
    xml.Borders do
      xml.Border 'ss:Position' => "Left", 'ss:LineStyle' => "Continuous", 'ss:Weight' => 1
    end
    xml.Alignment 'ss:Horizontal' => "Center"
  end
  xml.Style 'ss:ID' => "s31" do
    xml.Borders do
      xml.Border 'ss:Position' => "Left", 'ss:LineStyle' => "Continuous", 'ss:Weight' => 1
    end
  end
  xml.Style 'ss:ID' => "s32" do
    xml.Borders do
      xml.Border 'ss:Position' => "Left", 'ss:LineStyle' => "Continuous", 'ss:Weight' => 1
    end
    xml.Interior 'ss:Color' => "#1FB714", 'ss:Pattern' => "Solid"
    xml.Font 'ss:FontName' => "Verdana", 'ss:Bold' => 1
  end
end
xml.Worksheet 'ss:Name' => I18n.t(:tab_accounts) do
  xml.Table do
    unless @account.contacts.empty?
      xml.Column 'ss:Index' => 5, 'ss:Width' => 51
      xml.Column 'ss:Width' => 54
      xml.Column 'ss:Width' => 44
      xml.Column 'ss:Width' => 21, 'ss:Span' => 51

      # Header 1
      xml.Row 'ss:StyleID' => "s24" do
        
        xml.Cell 'ss:StyleID'=>"s28", 'ss:Index' => 8 do
          xml.Data "Semester 2 BSG", 
                    'ss:Type' => 'String'
        end
        #yellow background
        for i in 1..12
          xml.Cell 'ss:StyleID' => "s25"
        end
        xml.Cell 'ss:StyleID'=>"s32", 'ss:Index' => 21 do
          xml.Data "Semester 2 TBT", 
                    'ss:Type' => 'String'
        end
        #green background
        for i in 1..12
          xml.Cell 'ss:StyleID' => "s26"
        end
        
        xml.Cell 'ss:StyleID'=>"s28", 'ss:Index' => 34 do
          xml.Data "Semester 2 Munchies", 
                    'ss:Type' => 'String'
        end
        #yellow background
        for i in 1..12
          xml.Cell 'ss:StyleID' => "s25"
        end
        # xml.Cell 'ss:StyleID'=>"s32", 'ss:Index' => 47 do
        #   xml.Data "Semester 2 TBT",
        #             'ss:Type' => 'String'
        # end
        # #green background
        # for i in 1..12
        #   xml.Cell 'ss:StyleID' => "s26"
        # end
        
      end
      # Header.
      xml.Row 'ss:StyleID'=>"s27" do
        numbers = *(1..13)
        
        heads = [I18n.t('name'),
                 "Core",
                 "Leader",
                 "BSG",
                 "Last TBT",
                 "Last BSG",
                 "Neither"
               ]
        heads.concat(numbers)
        heads.concat(numbers)
        heads.concat(numbers)
        #heads.concat(numbers)
        heads.concat(registerables_heads)
        
        heads.each do |head|
          hash = head == 1 ? {'ss:StyleID' => "s29"} : {}
          xml.Cell hash do
            xml.Data head,
                     'ss:Type' => "#{head.respond_to?(:abs) ? 'Number' : 'String'}"
          end
        end
      end
      
      adelaide_leaders = ContactGroup.find_by_name("Adelaide Leaders")
      
      # Contact rows.
      @account.contacts.sort_by(&:first_name).each do |contact|
        tbt = contact.last_attendance_at_event_category("bible_talk")
        bsg = contact.last_attendance_at_event_category("bsg")
        tbt_by_weeks_s1 = contact.attendance_by_week_at_event_category("bible_talk", "1")
        tbt_by_weeks_s2 = contact.attendance_by_week_at_event_category("bible_talk", "2")
        
        bsg_by_weeks_s1 = contact.attendance_by_week_at_event_category("bsg", "1")
        munchies_by_weeks_s1 = contact.attendance_by_week_at_event_category("munchies", "1") 
        
        bsg_by_weeks_s2 = contact.attendance_by_week_at_event_category("bsg", "2")
        act_by_weeks_s2 = contact.attendance_by_week_at_event_category("act", "2")
        
        munchies_by_weeks_s2 = contact.attendance_by_week_at_event_category("munchies", "2") 
        
        core = contact.tag_list.include?("core") ? "Y" : ""
        leader = adelaide_leaders.memberships.find_by_contact_id(contact.id) ? "Y" : ""
        
        xml.Row do
          data    = [contact.name,
                     core,
                     leader,
                     #contact.tags.collect(&:name).join(", "),
                     contact.current_bsg,
                     (!tbt.nil? && tbt > (Time.now - 4.weeks)) ? tbt.strftime("%d/%m") : "",
                     (!bsg.nil? && bsg > (Time.now - 4.weeks)) ? bsg.strftime("%d/%m") : "",
                     (tbt.nil? && bsg.nil?) ? "True" : "False"]
                     
          data.concat(bsg_by_weeks_s2)
          data.concat(tbt_by_weeks_s2)
          data.concat(munchies_by_weeks_s2)
          #data.concat(tbt_by_weeks_s2)
          registerables.each do |e|
            data << (contact.registered_for?(e.id) ? "\u{2022}" : "")
          end
                     
          data.each_with_index do |value, index|
            hash = (index > 6) ? {'ss:StyleID' => "s21"} : {}
            hash = {'ss:StyleID' => "s30"} if (index == 7 || index == 20 || index == 33 || index == 46) 
            xml.Cell hash do
              xml.Data value,
                       'ss:Type' => "#{value.respond_to?(:abs) ? 'Number' : 'String'}"
            
            end
          end
        end
      end
    end
  end
end
