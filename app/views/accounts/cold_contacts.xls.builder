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
      xml.Column 'ss:Index' => 4, 'ss:Width' => 51
      xml.Column 'ss:Width' => 54
      xml.Column 'ss:Width' => 44
      xml.Column 'ss:Width' => 21, 'ss:Span' => 51

      # Header 1
      xml.Row 'ss:StyleID' => "s24" do
        #Semester 1
        
        xml.Cell 'ss:StyleID'=>"s28", 'ss:Index' => 7 do
          xml.Data "Semester 1 BSG", 
                    'ss:Type' => 'String'
        end
        #yellow background
        for i in 1..12
          xml.Cell 'ss:StyleID' => "s25"
        end
        xml.Cell 'ss:StyleID'=>"s32", 'ss:Index' => 20 do
          xml.Data "Semester 1 TBT", 
                    'ss:Type' => 'String'
        end
        #green background
        for i in 1..12
          xml.Cell 'ss:StyleID' => "s26"
        end
        
        #Semester 2
        
        xml.Cell 'ss:StyleID'=>"s28", 'ss:Index' => 33 do
          xml.Data "Semester 2 BSG/ACT", 
                    'ss:Type' => 'String'
        end
        #yellow background
        for i in 1..12
          xml.Cell 'ss:StyleID' => "s25"
        end
        xml.Cell 'ss:StyleID'=>"s32", 'ss:Index' => 46 do
          xml.Data "Semester 2 TBT", 
                    'ss:Type' => 'String'
        end
        #green background
        for i in 1..12
          xml.Cell 'ss:StyleID' => "s26"
        end
        
      end
      # Header.
      xml.Row 'ss:StyleID'=>"s27" do
        numbers = *(1..13)
        heads = [I18n.t('name'),
                 I18n.t('email'),
                 I18n.t('mobile'),
                 "Last TBT",
                 "Last BSG",
                 "Neither"
               ]
        heads.concat(numbers)
        heads.concat(numbers)
        heads.concat(numbers)
        heads.concat(numbers)
        
        heads.each do |head|
          hash = head == 1 ? {'ss:StyleID' => "s29"} : {}
          xml.Cell hash do
            xml.Data head,
                     'ss:Type' => "#{head.respond_to?(:abs) ? 'Number' : 'String'}"
          end
        end
      end
      
      # Contact rows.
      @account.contacts.sort_by(&:first_name).each do |contact|
        tbt = contact.last_attendance_at_event_category("bible_talk")
        bsg = contact.last_attendance_at_event_category("bsg")
        tbt_by_weeks_s1 = contact.attendance_by_week_at_event_category("bible_talk", "1")
        tbt_by_weeks_s2 = contact.attendance_by_week_at_event_category("bible_talk", "2")
        
        bsg_by_weeks_s1 = contact.attendance_by_week_at_event_category("bsg", "1") 
        
        bsg_by_weeks_s2 = contact.attendance_by_week_at_event_category("bsg", "2")
        act_by_weeks_s2 = contact.attendance_by_week_at_event_category("act", "2")
        
        bsg_by_weeks_s2 = bsg_by_weeks_s2.each_with_index.map{|v,i| v.empty? ? act_by_weeks_s2[i] : v }
        
        xml.Row do
          data    = [contact.name,
                     contact.email,
                     contact.mobile,
                     (!tbt.nil? && tbt > (Time.now - 4.weeks)) ? tbt.strftime("%d/%m") : "",
                     (!bsg.nil? && bsg > (Time.now - 4.weeks)) ? bsg.strftime("%d/%m") : "",
                     (tbt.nil? && bsg.nil?) ? "True" : "False"]
                     
          data.concat(bsg_by_weeks_s1)
          data.concat(tbt_by_weeks_s1)
          data.concat(bsg_by_weeks_s2)
          data.concat(tbt_by_weeks_s2)
                     
          data.each_with_index do |value, index|
            hash = (index > 5) ? {'ss:StyleID' => "s21"} : {}
            hash = {'ss:StyleID' => "s30"} if (index == 6 || index == 19 || index == 32 || index == 45) 
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
