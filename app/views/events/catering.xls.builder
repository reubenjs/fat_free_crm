xml.Worksheet 'ss:Name' => (@event.name + " contact list") do
  xml.Table do
    unless @event.contacts.empty?
      day_names = %w(Mon Tue Wed Thu Fri)
      meal_names = %w(Breakfast Lunch Dinner)
      
      # Header
      xml.Row do
        ["Day", "Meal", "Total Meals", "First Name", "Last Name", "Details"].each do |head|
        
          xml.Cell do
            xml.Data head, 'ss:Type' => 'String'
          end
        end
      end
      
      # Contact rows.
      day_names.each do |day|
        meal_names.each do |meal|
          contacts = @event.contacts_eating_at(meal, day)
          
          # Day, meal, total meals
          xml.Row do
            data = [day, meal, contacts.try(&:count)]
            
            data.each do |value|
              xml.Cell do
                xml.Data value, 'ss:Type' => 'String'
              end
            end
          end
          
          contacts_with_req = contacts.where(:cf_has_dietary_or_health_issues => true)
          
          contacts_with_req.each do |contact|
            xml.Row do
              data = ["", "", "", contact.first_name, contact.last_name, contact.cf_dietary_health_issue_details]
          
              data.each do |value|
                xml.Cell do
                  xml.Data value,
                           'ss:Type' => 'String'
                end
              end
            end
          end
          
          xml.Row
          
        end
      end
      
    end
  end
end
