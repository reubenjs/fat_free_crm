# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
module ContactsHelper
  
  # Sidebar checkbox control for filtering contacts by folder.
  #----------------------------------------------------------------------------
  def contact_folder_checbox(folder, count)
    id = (folder == "other") ? "other" : folder.id
    checked = (session[:contacts_filter] ? session[:contacts_filter].split(",").include?(id.to_s) : count.to_i > 0)
    onclick = remote_function(
      :url      => { :controller => :contacts, :action => :filter },
      :with     => h(%Q/"folder=" + $$("input[name='folder[]']").findAll(function (el) { return el.checked }).pluck("value")/),
      :loading  => "$('loading').show()",
      :complete => "$('loading').hide()"
    )
    
    check_box_tag("folder[]", id, checked, :id => id, :onclick => onclick)
  end
  
  # Sidebar checkbox control for filtering contacts by folder.
  #----------------------------------------------------------------------------
  def user_contact_checbox(user, count)
    id = (user == "other") ? "other" : user.id
    checked = (session[:contacts_user_filter] ? session[:contacts_user_filter].split(",").include?(id.to_s) : count.to_i > 0)
    onclick = remote_function(
      :url      => { :controller => :contacts, :action => :filter },
      :with     => h(%Q/"user=" + $$("input[name='user[]']").findAll(function (el) { return el.checked }).pluck("value")/),
      :loading  => "$('loading').show()",
      :complete => "$('loading').hide()"
    )
    
    check_box_tag("user[]", id, checked, :id => id, :onclick => onclick)
  end
  
  def label_folder_select(folder, text)
    ids = folder.class == Account ? [folder.id.to_s] : [folder.to_s]
    contact_folder_checbox_select(text, ids)
  end
  
  def label_user_select(user, text)
    ids = user.class == User ? [user.id.to_s] : [user.to_s]
    contact_user_checbox_select(text, ids)
  end
  
  def contact_user_checbox_select(text, ids = [], html_class = "filter_label")
    onclick = remote_function(
      :url      => { :controller => :contacts, :action => :filter },
      :with     => h(%Q/"user=" + $$("input[name='user[]']").findAll(function (el) { el.checked = ((#{ids}.indexOf(el.value) >= 0) ? true : false); return el.checked; }).pluck("value")/),
      :loading  => "$('loading').show()",
      :complete => "$('loading').hide()"
    )
    
    label_tag(text.to_sym, text, :onclick => onclick, :class => html_class)
  end
  
  
  def contact_folder_checbox_select(text, ids = [], html_class = "filter_label")
    onclick = remote_function(
      :url      => { :controller => :contacts, :action => :filter },
      :with     => h(%Q/"folder=" + $$("input[name='folder[]']").findAll(function (el) { el.checked = ((#{ids}.indexOf(el.value) >= 0) ? true : false); return el.checked; }).pluck("value")/),
      :loading  => "$('loading').show()",
      :complete => "$('loading').hide()"
    )
    
    label_tag(text.to_sym, text, :onclick => onclick, :class => html_class)
  end
  
  #----------------------------------------------------------------------------
  def link_to_graduate(record, options = {})
    object = record.is_a?(Array) ? record.last : record
    confirm = options[:confirm] || nil

    link_to("Graduate",
      options[:url] || graduate_contact_path(record),
      :method => :post,
      :remote => true,
      #:onclick => visual_effect(:highlight, dom_id(object), :startcolor => "#ffe4e1"),
      :confirm => confirm
    )
  end
  
  #----------------------------------------------------------------------------
  def link_to_confirm(contact)
    link_to(t(:delete) + "?", confirm_contact_path(contact), :method => :get, :remote => true)
  end
  
  #----------------------------------------------------------------------------
  def link_to_mailing_lists(contact)
    link_to(image_tag("/assets/mail_edit.png", :size => "16x12"), 
            mailing_lists_contact_path(contact), 
            :method => :get, 
            :remote => true)
  end
  
  #----------------------------------------------------------------------------
  def link_to_tags(contact)
    link_to(image_tag("/assets/tag_blue_edit.png", :size => "12x12"), 
            tags_contact_path(contact), 
            :method => :get, 
            :remote => true)
  end
  
  # Contact summary for RSS/ATOM feeds.
  #----------------------------------------------------------------------------
  def contact_summary(contact)
    summary = [""]
    summary << contact.title.titleize if contact.title?
    summary << contact.department if contact.department?
    if contact.account && contact.account.name?
      summary.last << " #{t(:at)} #{contact.account.name}"
    end
    summary << contact.email if contact.email.present?
    summary << "#{t(:phone_small)}: #{contact.phone}" if contact.phone.present?
    summary << "#{t(:mobile_small)}: #{contact.mobile}" if contact.mobile.present?
    summary.join(', ')
  end
  
  def contact_template_link(template, text)
    templates = { 
        :adelaide => {:folder => "Adelaide", :weekly_emails => ["adelaide"], :supporter_emails => []},
        :city_west => {:folder => "City West", :weekly_emails => ["city_west"], :supporter_emails => []},
        :city_east => {:folder => "City East", :weekly_emails => ["city_east"], :supporter_emails => []},
        :supporter => {:folder => "Supporters", :weekly_emails => [], :supporter_emails => ["tt_email","prayer_points"]}
      }
    
      link_to(text, "", :remote => true, :onclick => 
          contact_template_jscript(
            templates[template.to_sym][:folder],
            templates[template.to_sym][:weekly_emails],
            templates[template.to_sym][:supporter_emails]
          ))
    
  end
  
  def contact_template_jscript(template, weekly_emails=[], supporter_emails=[])
    weekly_checkboxes = %w(adelaide city_west city_east)
    supporter_checkboxes = %w(tt_email prayer_points)
    
    # seems that prototype update event is required...
    script = "
      $j('\#account_id').val(#{Account.find_by_name(template).id});
      Event.fire($(\"account_id\"), \"liszt:updated\");
      $j('\#account_id').trigger(\"change\");
    "
    
    # clear all subscriptions
    weekly_checkboxes.each do |box|
      script = script + "$j('\#contact_cf_weekly_emails_#{box}').prop(\"checked\", false);"
    end
    
    supporter_checkboxes.each do |box|
      script = script + "$j('\#contact_cf_supporter_emails_#{box}').prop(\"checked\", false);"
    end
    
    # subscribe according to template
    weekly_emails.each do |email|
      script = script + "$j('\#contact_cf_weekly_emails_#{email}').prop(\"checked\", true);"
    end
    
    supporter_emails.each do |email|
      script = script + "$j('\#contact_cf_supporter_emails_#{email}').prop(\"checked\", true);"
    end
    
    script
  end
  
end

