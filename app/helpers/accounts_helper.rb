# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
module AccountsHelper

  # Sidebar checkbox control for filtering accounts by category.
  #----------------------------------------------------------------------------
  def account_category_checkbox(category, count)
    entity_filter_checkbox(:category, category, count)
  end

  # Quick account summary for RSS/ATOM feeds.
  #----------------------------------------------------------------------------
  def account_summary(account)
    [ number_to_currency(account.opportunities.pipeline.map(&:weighted_amount).sum, :precision => 0),
      t(:added_by, :time_ago => time_ago_in_words(account.created_at), :user => account.user_id_full_name),
      t('pluralize.contact', account.contacts.count),
      t('pluralize.opportunity', account.opportunities.count),
      t('pluralize.comment', account.comments.count)
    ].join(', ')
  end

  # Generates a select list with the first 25 accounts
  # and prepends the currently selected account, if any.
  #----------------------------------------------------------------------------
  def account_select(options = {})
      options[:selected] = (@account && @account.id) || 0
      accounts = ([@account] + Account.my.order(:name).limit(25)).compact.uniq
      collection_select :account, :id, accounts, :id, :name, options,
                        {:"data-placeholder" => t(:select_an_account),
                         :"data-url" => auto_complete_accounts_path(format: 'json'),
                         :style => "width:#{mobile_device? ? "245" : "324"}px; display:none;",
                         :class => 'ajax_chosen' }
  end
  
  def set_campus
    "if (campus_text_box = $('contact_cf_campus')) { 
      var sel = $('account_id_chzn').select('.result-selected')[0].outerText;
      var included_folders = #{Setting.included_folders};
      if (included_folders.indexOf(sel) >= 0) {
        if ( $('field_group_7_container').select('.field_group')[0].style['display'] == 'none') {
          crm.flip_subtitle($('field_group_7_container').select('a')[0])
        }
        campus_text_box.value = sel;
        campus_text_box.highlight().shake({distance:6});
      }
    }"
  end

  # Select an existing account or create a new one.
  #----------------------------------------------------------------------------
  def account_select_or_create(form, &block)
    options = {}
    width = mobile_device? ? "245" : "324"
    yield options if block_given?

    content_tag(:div, :class => 'label') do
      t(:account).html_safe +

      content_tag(:span, :id => 'account_create_title') do
        "(#{t :create_new} #{t :or} <a href='#' onclick='crm.select_account(1); return false;'>#{t :select_existing}</a>):".html_safe
      end.html_safe +

      content_tag(:span, :id => 'account_select_title') do
        "(<a href='#' onclick='crm.create_account(1); return false;'>#{t :create_new}</a> #{t :or} #{t :select_existing}):".html_safe
      end.html_safe +

      content_tag(:span, ':', :id => 'account_disabled_title').html_safe
    end.html_safe +
    
    account_select(options).html_safe +
    form.text_field(:name, :style => "width:#{width}px; display:none;")
  end

  # Output account url for a given contact
  # - a helper so it is easy to override in plugins that allow for several accounts
  #----------------------------------------------------------------------------
  def account_with_url_for(contact)
    contact.account ? link_to(h(contact.account.name), account_path(contact.account)) : ""
  end

  # Output account with title and department
  # - a helper so it is easy to override in plugins that allow for several accounts
  #----------------------------------------------------------------------------
  def account_with_title_and_department(contact)
    text = if !contact.title.blank? && contact.account
        # works_at: "{{h(job_title)}} at {{h(company)}}"
        content_tag :div, t(:works_at, :job_title => h(contact.title), :company => account_with_url_for(contact)).html_safe
      elsif !contact.title.blank?
        content_tag :div, h(contact.title)
      elsif contact.account
        content_tag :div, account_with_url_for(contact)
      else
        ""
      end
    text << t(:department_small, h(contact.department)) unless contact.department.blank?
    text
  end

  # "title, department at Account name" used in index_brief and index_long
  # - a helper so it is easy to override in plugins that allow for several accounts
  #----------------------------------------------------------------------------
  def brief_account_info(contact)
    text = ""
    title = contact.title
    department = contact.department
    account = contact.account
    account_text = ""
    account_text = link_to_if(can?(:read, account), h(account.name), account_path(account)) if account.present?

    text << if title.present? && department.present?
          t(:account_with_title_department, :title => h(title), :department => h(department), :account => account_text)
        elsif title.present?
          t(:account_with_title, :title => h(title), :account => account_text)
        elsif department.present?
          t(:account_with_title, :title => h(department), :account => account_text)
        elsif account_text.present?
          t(:works_at, :job_title => "", :company => account_text)
        else
          ""
        end
    text.html_safe
  end

end
