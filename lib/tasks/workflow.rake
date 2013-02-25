# Fat Free CRM
# Copyright (C) 2008-2011 by Michael Dvorkin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#------------------------------------------------------------------------------
namespace :ffcrm do
  namespace :saasu do
    desc "sync contacts with saasu."
    task :sync => :environment do
      # This doesn't delete records from saasu, but will push any contacts in
      # mojo that are missing
      Saasu::Base.api_key = Setting.saasu[:access_key]
      Saasu::Base.file_uid = Setting.saasu[:file_id]
      
      puts "#{Time.now} Getting contacts from Saasu"
      saasu_contacts = Saasu::Contact.all
      
      excluded = ["Supporters", "2012 Graduates"]
      excluded_accounts = Account.where('name IN (?)', excluded).collect{|a| a.id}
      crm_contacts = Contact.includes(:account).where('accounts.id NOT IN (?)', excluded_accounts)
      
      puts "#{Time.now} Calculating changes"
      saasu_contacts.each do |c|
        crm_contacts.delete_if{|item| item.saasu_uid == c.uid}
      end
      
      crm_contacts.each do |c|
        sc = Saasu::Contact.new
        sc.given_name = c.first_name
        sc.family_name = c.last_name
        sc.email_address = c.email
        sc.email = c.email
        sc.mobile_phone = c.mobile
        sc.main_phone = c.mobile
        sc.home_phone = c.phone
        result = Saasu::Contact.insert(sc)
        if result.errors.nil?
          puts "#{Time.now} Added contact #{c.full_name} to saasu"
        else
          puts "#{Time.now} Error adding contact #{c.full_name} to saasu. #{result.errors}"
        end
        
        c.saasu_uid = result.inserted_entity_uid
        c.save!
      end
      
    end
  end
  
  namespace :mailchimp do
    desc "check mailchimp lists for consistency"
    task :check => :environment do
      lists = ["adelaide", "city_west", "city_east"]
      
      lists.each do |list|
        list_id = Setting.mailchimp["#{list}_list_id"]
        list_key = Setting.mailchimp["#{list}_api_key"]

        api = Mailchimp::API.new(list_key, :throws_exceptions => true)
        r = api.list_members(:id => list_id, :limit => "1000")
        emails_at_mailchimp = r["data"].collect.each { |lm| lm["email"].gsub(/\s+/, "").downcase }
        
        list_contacts = Contact.where("cf_weekly_emails LIKE ?", "%#{list.titleize}%")
        emails_in_crm = list_contacts.collect.each { |c| c.email.to_s.gsub(/\s+/, "").downcase }
        emails_in_crm.reject!(&:blank?)
        
        subscribed_with_no_email = Contact.where("cf_weekly_emails LIKE ? AND email IS NULL", "%#{list.titleize}%")
        invalids = subscribed_with_no_email.collect.each { |c| c.first_name + " " + c.last_name}
        
        puts "*******************************"
        puts "*** LIST: #{list.titleize} ****"
        puts "*******************************"
        puts "\n"
        puts "emails at mailchimp, but not in crm:"
        puts "____________________________________"
        puts (emails_at_mailchimp - emails_in_crm).join("\n")
        puts "\n"
        puts "emails in crm, but not at mailchimp:"
        puts "____________________________________"
        puts (emails_in_crm - emails_at_mailchimp).join("\n")
        puts "\n"
        puts "subscribed to list in CRM, but no email address (invalid):"
        puts "____________________________________"
        puts (invalids).join("\n")
        puts "\n"
        
      end
      
    end
  end
  
  namespace :gonecold do
    desc "Scan for contacts that have gone cold"
    task :find => :environment do
      # Load fixtures
      require 'active_record/fixtures'
      campuses = []
      #campuses << Account.find_by_name("Adelaide Uni")
      campuses << Account.find_by_name("City East")
      campuses << Account.find_by_name("City West")
      campuses -= [nil]
      
      campuses.each do |campus|
        campus.contacts.each do |contact|
          last_time_at_tbt = contact.last_attendance_at_event_category(:bible_talk)
          last_time_at_bsg = contact.last_attendance_at_event_category(:bsg)
          things_missed = []
          things_missed << "TBT" if last_time_at_tbt.nil?
          things_missed << "BSG" if last_time_at_bsg.nil?
          
          if last_time_at_tbt.nil? || last_time_at_bsg.nil? || last_time_at_tbt < (Time.now - 2.weeks) || last_time_at_bsg < (Time.now - 2.weeks)
            if contact.tasks.where('name LIKE (?)', "Has not been at%").empty?
              contact.tasks << Task.new(
                    :user => User.find(1), 
                    :name => "Has not been at #{things_missed.to_sentence(:two_words_connector => " or ")} during the last 2 weeks", 
                    :category => :follow_up, 
                    :bucket => "due_this_week"
                    ) 
              contact.save
              puts "#{contact.first_name} #{contact.last_name} has gone cold on #{things_missed.to_sentence}"
            end
          end
        end
      end  
      puts "Done checking cold contacts"
    end
  end
  
  namespace :registrations do
    desc "sync registrants from website registration data"
    task :sync => :environment do
      
      require 'open-uri'
      PaperTrail.whodunnit = 1
      url = Setting.registration_api[:ccamp_link]
      url_data = open(url).read()
      
      group = ContactGroup.find_or_initialize_by_name(
          :name => "Commencement Camp 2013",
          :access => Setting.default_access,
          :user_id => 1
          )
        unless group.persisted?
          group.save
        end
      
      csv = CSV.parse(url_data, {:col_sep => ',', :headers => :first_row, :header_converters => :symbol}) 
      csv.each do |row|
        unless group.contacts.find_by_email(row[:_email])
        #sync has already brought this contact in and placed it in the group, skip...
          contact = Contact.find_by_email(row[:_email])
          if contact.nil?
            contact = Contact.find_or_initialize_by_mobile(row[:_mobile].gsub(/[\(\) ]/, ""))
            contact.update_attributes(:alt_email => contact.email) if contact.persisted? #email must have changed
            log_string = "Contact found by mobile. updated: "
          end
          
          if row[:_course_year_in_2013] == "1"
            contact.cf_year_commenced = "2013"
          end
          
          contact.business_address = Address.new
          contact.business_address.street1 = row[:_address]
          contact.business_address.street2 = row[:_address2]
          contact.business_address.city = row[:_suburb]
          contact.business_address.state = row[:_state]
          contact.business_address.zipcode = row[:_post_code]
          contact.business_address.country = "Australia"
          contact.business_address.address_type = "Business"   
          
          unless contact.assigned_to.present?
            if (row[:_campus] == "City East" || row[:_campus] == "City West")
              contact.cf_weekly_emails << row[:_campus] unless contact.cf_weekly_emails.include?(row[:_campus])
              user = User.find_by_first_name("dave")
            elsif (row[:_campus] == "Adelaide")
              contact.cf_weekly_emails << row[:_campus] unless contact.cf_weekly_emails.include?(row[:_campus])
              user = (row[:_gender] == "Male") ? User.find_by_first_name("reuben") : User.find_by_first_name("laura")
            else
              user = User.find_by_first_name("geoff")
            end
            contact.assigned_to = user.id#reuben or laura
          end
          
          unless contact.account.present?
            contact.account = Account.find_or_create_by_name(row[:_campus]) 
            contact.account.user = User.find(1)
          end
          
          if !contact.persisted?
            contact.user_id = 1
            contact.access = Setting.default_access
            contact.tag_list << "new@cc13" unless contact.tag_list.include?("new@cc13")
            log_string = "Created new contact: "
          else
            log_string = "Contact found by email. updated: " if log_string.nil?
          end
          
          contact.update_attributes(
            :first_name => row[:_first_name],
            :last_name => row[:_last_name],
            :email => row[:_email],
            :cf_gender => row[:_gender],
            :phone => row[:_home_phone],
            :mobile => row[:_mobile].gsub(/[\(\) ]/, ""),
            #address?
            :cf_campus => row[:_campus],
            :cf_course_1 => row[:_course],
            :cf_church_affiliation => row[:_church_if_you_attend_one],
            :cf_expected_grad_year => row[:_year_i_expect_to_graduate]
           )

          if row[:_is_this_your_first_commencement_camp] == "Yes"
            contact.tag_list << "first-ccamp-2013" unless contact.tag_list.include?("first-ccamp-2013")
          end
          
          puts (log_string + contact.first_name + " " + contact.last_name)
          
          contact.save
          
          contacts_with_name = Contact.where(:first_name => contact.first_name, :last_name => contact.last_name)
          if contacts_with_name.size > 1
            contact.tasks << Task.new(
                  :name => "Possible duplicate from registration sync", :category => :follow_up, :bucket => "due_this_week", :user => User.find_by_first_name("reuben")
                  )
          end
          
          group.contacts << contact unless group.contacts.include?(contact) #shouldn't happen, but just in case
        end
      end  
    end
    
    desc "sync oweek contacts from website registration data"
    task :sync_oweek => :environment do
      
      require 'open-uri'
      PaperTrail.whodunnit = 1
      url = Setting.registration_api[:oweek_link]
      url_data = open(url).read()
      
      group = ContactGroup.find_or_initialize_by_name(
          :name => "OWeek 2013",
          :access => Setting.default_access,
          :user_id => 1
          )
        unless group.persisted?
          group.save
        end
      
      csv = CSV.parse(url_data, {:col_sep => ',', :headers => :first_row, :header_converters => :symbol}) 
      csv.each do |row|
        unless SyncLog.find_by_sync_type_and_synced_item("ow13", row[:uniq_id])
        #sync has already brought this contact in and placed it in the group, skip...
          contact = row[:email].blank? ? nil : Contact.find_by_email(row[:email])
          if contact.nil?
            if row[:mobile].blank?
              contact = Contact.new
              log_string = "Contact initialized"
            else
              contact = Contact.find_or_initialize_by_mobile(row[:mobile].gsub(/[\(\) ]/, ""))
              contact.update_attributes(:alt_email => contact.email) if contact.persisted? #email must have changed
              log_string = "Contact found by mobile. updated: "
            end
          end
          
          if row[:year] == "1"
            contact.cf_year_commenced = "2013"
          end  
          
          unless contact.assigned_to.present?
            if (row[:add_to_email] == "checked" && row[:campus] == "City East" || row[:campus] == "City West")
              #contact.cf_weekly_emails << row[:_campus] unless contact.cf_weekly_emails.include?(row[:_campus])
              user = User.find_by_first_name("dave")
            elsif (row[:add_to_email] == "checked" && row[:campus] == "Adelaide")
              #contact.cf_weekly_emails << row[:_campus] unless contact.cf_weekly_emails.include?(row[:_campus])
              user = (row[:gender] == "Male") ? User.find_by_first_name("reuben") : User.find_by_first_name("laura")
            else
              user = User.find_by_first_name("geoff")
            end
            contact.assigned_to = user.id#reuben or laura
          end
          
          unless contact.account.present?
            contact.account = Account.find_or_create_by_name(row[:campus]) 
            contact.account.user = User.find(1)
          end
          
          if !contact.persisted?
            contact.user_id = 1
            contact.access = Setting.default_access
            contact.tag_list << "new@ow13" unless contact.tag_list.include?("new@ow13")
            log_string = "Created new contact: "
          else
            log_string = "Contact found by email. updated: " if log_string.nil?
          end
          
          if row[:learn_more] == "checked"
            contact.tag_list << "learn_more" unless contact.tag_list.include?("learn_more")
            contact.tag_list << row[:learn_more_option].gsub(/ /, "_") unless contact.tag_list.include?(row[:learn_more_option].gsub(/ /, "_"))
          end
           
          if row[:international] == "checked"
            contact.tag_list << "international" unless contact.tag_list.include?("international")
          end
          
          contact.update_attributes(
            :first_name => row[:first_name],
            :last_name => row[:last_name],
            :email => row[:email],
            :cf_gender => row[:gender],
            :mobile => row[:mobile].gsub(/[\(\) ]/, ""),
            #address?
            :cf_campus => row[:campus],
            :cf_course_1 => row[:course],
            :cf_church_affiliation => row[:church],
            :cf_student_number => row[:student_id]
           )
           
          puts (log_string + contact.first_name + " " + contact.last_name)
          
          puts contact.save! ? "saved ok" : "save problem"
          
          unless row[:comments].blank?
            contact.comments.create(:comment => row[:comments], :user_id => 1)
          end
          
          contact.touch
          
          sl = SyncLog.create(:sync_type => "ow13", :synced_item => row[:uniq_id])
          sl.save
          
          contacts_with_name = Contact.where(:first_name => contact.first_name, :last_name => contact.last_name)
          if contacts_with_name.size > 1
            contact.tasks << Task.new(
                  :name => "Possible duplicate from registration sync", :category => :follow_up, :bucket => "due_this_week", :user => User.find_by_first_name("reuben")
                  )
          end
          
          group.contacts << contact unless group.contacts.include?(contact) #shouldn't happen, but just in case
        end
      end  
    end
    
    task :fix_tags => :environment do
      require 'open-uri'
      PaperTrail.whodunnit = 1
      url = Setting.registration_api[:ccamp_link]
      url_data = open(url).read()
      
      group = ContactGroup.find_or_initialize_by_name(
          :name => "Commencement Camp 2013",
          :access => Setting.default_access,
          :user_id => 1
          )
        unless group.persisted?
          group.save
        end
      
      csv = CSV.parse(url_data, {:col_sep => ',', :headers => :first_row, :header_converters => :symbol}) 
      csv.each do |row|
        #unless group.contacts.find_by_email(row[:_email])
        #sync has already brought this contact in and placed it in the group, skip...
        contact = Contact.find_by_email(row[:_email])
        
        if row[:_is_this_your_first_commencement_camp] == "Yes"
          contact.tag_list << "first-ccamp-2013" unless contact.tag_list.include?("first-ccamp-2013")
        end
        
        puts (contact.first_name + " " + contact.last_name)
        
        contact.save
      end
    end
    
    task :non_cc => :environment do
      PaperTrail.whodunnit = 1
      
      group = ContactGroup.find(10)
      
      registered = Contact.includes(:contact_groups).where('contact_groups.id IN (5)')
      all_nt = Contact.includes(:account).where('accounts.id IN (3,2,1)')
      
      not_registered = all_nt - registered
      
      group.contacts << not_registered
      
    end
    
  end
  
  task :fix_faculty => :environment do
    PaperTrail.whodunnit = 1
      
      
    csv = CSV.foreach(FatFreeCRM.root.join('db/data-import/adelaide-faculty.csv'), {:col_sep => ',', :headers => :first_row, :header_converters => :symbol}) do |row|
      #unless group.contacts.find_by_email(row[:_email])
      #sync has already brought this contact in and placed it in the group, skip...
      contact = Contact.find(row[:id])
        
      contact.cf_faculty = row[:cf_faculty]
      contact.cf_course_1 = row[:cf_course_1]
      contact.cf_course_2 = row[:cf_course_2]
        
      puts (contact.first_name + " " + contact.last_name)
        
      contact.save
    end
  end
  
end
