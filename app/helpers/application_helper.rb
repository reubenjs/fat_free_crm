# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
module ApplicationHelper

  def tabs(tabs = nil)
    tabs ||= controller_path =~ /admin/ ? FatFreeCRM::Tabs.admin : FatFreeCRM::Tabs.main
    if tabs
      @current_tab ||= tabs.first[:text] # Select first tab by default.
      tabs.each { |tab| tab[:active] = (@current_tab == tab[:text] || @current_tab == tab[:url][:controller]) }
    else
      raise FatFreeCRM::MissingSettings, "Tab settings are missing, please run <b>rake ffcrm:setup</b> command."
    end
  end

  #----------------------------------------------------------------------------
  def tabless_layout?
    %w(authentications passwords).include?(controller.controller_name) ||
    ((controller.controller_name == "users") && (%w(create new).include?(controller.action_name)))
  end

  # Show existing flash or embed hidden paragraph ready for flash[:notice]
  #----------------------------------------------------------------------------
  def show_flash(options = { :sticky => false })
    [:error, :warning, :info, :notice].each do |type|
      if flash[type]
        html = content_tag(:div, h(flash[type]), :id => "flash")
        flash[type] = nil
        return html << content_tag(:script, "crm.flash('#{type}', #{options[:sticky]})".html_safe, :type => "text/javascript")
      end
    end
    content_tag(:p, nil, :id => "flash", :style => "display:none;")
  end

  #----------------------------------------------------------------------------
  def subtitle(id, hidden = true, text = id.to_s.split("_").last.capitalize)
    content_tag("div",
      link_to("<small>#{ hidden ? "&#9658;" : "&#9660;" }</small> #{text}".html_safe,
        url_for(:controller => :home, :action => :toggle, :id => id),
        :remote => true,
        :onclick => "crm.flip_subtitle(this)"
      ), :class => "subtitle")
  end

  #----------------------------------------------------------------------------
  def section(related, assets, no_select=false, views=false, sort_by_model=Contact, no_create=false)
    asset = assets.to_s.singularize
    asset_title = (related.class == Event && assets == :contacts) ? "Registrations" : assets
    create_id  = "create_#{asset}"
    select_id  = "select_#{asset}"
    create_url = controller.send(:"new_#{asset}_path")
    asset_count = related.try(assets).count
    
    if (views && related.present?)
      sort_by_menu_items = sort_by_model.sort_by_fields.map { |field| options_menu_item(:sort_by, field, url_for(:controller => related.class.name.tableize.to_sym, :action => :redraw_show, :id => related.id, :remote => true)) }
      sort_by = current_user.pref[:"#{sort_by_model.name.tableize}_sort_by"]  || sort_by_model.sort_by
      current_sort_by = t("option_" + sort_by_model.sort_by_map.invert[sort_by])
    end

    html = tag(:br)
    html << content_tag(:div, view_buttons, :class => :subtitle_tools, :id => "buttons") if views
    html << content_tag(:div, "&nbsp;|&nbsp;".html_safe, :class => "subtitle_tools") if views
    html << content_tag(:div, t(:sort_by, :models => t(:"#{controller_name}_small"), :field => link_to(current_sort_by, "#", :id => :sort_by)).html_safe , :class => "subtitle_tools") if (views && related.present?)
    html << content_tag(:div, "&nbsp;|&nbsp;".html_safe, :class => "subtitle_tools") if (views && related.present? && !no_create)
    html << javascript_tag(
      "new crm.Menu({
        trigger   : \"\#sort_by\",
        fade      : 500,
        appear    : 500,
        menu_items: [ #{sort_by_menu_items.join(",")} ]
      });" 
    ) if (views && related.present?)
    html << content_tag(:div, link_to(t(select_id), "#", :id => select_id), :class => "subtitle_tools") unless no_select
    html << content_tag(:div, "&nbsp;|&nbsp;".html_safe, :class => "subtitle_tools") unless no_select
    html << content_tag(:div, link_to_inline(create_id, create_url, :related => dom_id(related), :text => t(create_id)), :class => "subtitle_tools") unless no_create
    html << content_tag(:div, (asset_count > 0 ? t(asset_title) + " (#{asset_count})" : t(assets)), :class => :subtitle, :id => "create_#{asset}_title")
    html << content_tag(:div, "", :class => :remote, :id => create_id, :style => "display:none;")
  end

  #----------------------------------------------------------------------------
  def load_select_popups_for(related, *assets)
    js = generate_js_for_popups(related, *assets)
    content_for(:javascript_epilogue) do
      raw "$(function() { #{js} });"
    end
  end

  def generate_js_for_popups(related, *assets)
    assets.map do |asset|
      render(:partial => "shared/select_popup", :locals => { :related => related, :popup => asset })
    end.join
  end

  # We need this because standard Rails [select] turns &#9733; into &amp;#9733;
  #----------------------------------------------------------------------------
  def rating_select(name, options = {})
    stars = Hash[ (1..5).map { |star| [ star, "&#9733;" * star ] } ].sort
    options_for_select = %Q(<option value="0"#{options[:selected].to_i == 0 ? ' selected="selected"' : ''}>#{t :select_none}</option>)
    options_for_select << stars.map { |star| %(<option value="#{star.first}"#{options[:selected] == star.first ? ' selected="selected"' : ''}>#{star.last}</option>) }.join
    select_tag name, options_for_select.html_safe, options
  end

  #----------------------------------------------------------------------------
  def link_to_inline(id, url, options = {})
    text = options[:text] || t(id, :default => id.to_s.titleize)
    text = (arrow_for(id) + text) unless options[:plain]
    related = (options[:related] ? "&related=#{options[:related]}" : '')
    event_instance = (options[:event_instance_id] ? "&event_instance_id=#{options[:event_instance_id]}" : '')
    
    link_to(text,
      url + "#{url.include?('?') ? '&' : '?'}cancel=false" + related + event_instance,
      :remote => true,
      :onclick => "this.href = this.href.replace(/cancel=(true|false)/,'cancel='+ ($('##{id}').css('display') != 'none'));",
      :class => options[:class]
    )
  end

  #----------------------------------------------------------------------------
  def arrow_for(id)
    content_tag(:span, "&#9658;".html_safe, :id => "#{id}_arrow", :class => :arrow)
  end

  #----------------------------------------------------------------------------
  def link_to_edit(record, options = {})
    object = record.is_a?(Array) ? record.last : record
    related = (options[:related] ? "&related=#{options[:related]}" : '')
    edit_text = options[:edit_text] ? options[:edit_text] : t(:edit)
    
    name = (params[:klass_name] || object.class.name).underscore.downcase
    link_to(edit_text,
      options[:url] || polymorphic_url(record, :action => :edit),
      :remote  => true,
      :onclick => "this.href = this.href.split('?')[0] + '?previous='+crm.find_form('edit_#{name}') + '#{related}';".html_safe
    )
  end

  #----------------------------------------------------------------------------
  def link_to_delete(record, options = {})
    object = record.is_a?(Array) ? record.last : record
    confirm = options[:confirm] || nil

    link_to(t(:delete) + "!",
      options[:url] || url_for(record),
      :method => :delete,
      :remote => true,
      :confirm => confirm
    )
  end

  #----------------------------------------------------------------------------
  def link_to_discard(object, discard_text="Discard")
    current_url = (request.xhr? ? request.referer : request.fullpath)
    parent, parent_id = current_url.scan(%r|/(\w+)/(\d+)|).flatten

    link_to(discard_text,
      url_for(:controller => parent, :action => :discard, :id => parent_id, :attachment => object.class.name, :attachment_id => object.id),
      :method  => :post,
      :remote  => true
    )
  end

  #----------------------------------------------------------------------------
  def link_to_cancel(url, params = {})
    url = params[:url] if params[:url]
    link_to(t(:cancel),
      url + "#{url.include?('?') ? '&' : '?'}cancel=true",
      :remote => true
    )
  end

  #----------------------------------------------------------------------------
  def link_to_close(url)
    link_to("x", url + "#{url.include?('?') ? '&' : '?'}cancel=true",
      :remote => true,
      :class => "close",
      :title => t(:close_form)
    )
  end

  # Bcc: to dropbox address if the dropbox has been set up.
  #----------------------------------------------------------------------------
  def link_to_email(email, length = nil, &block)
    name = (length ? truncate(email, :length => length) : email)
    if Setting.email_dropbox && Setting.email_dropbox[:address].present?
      mailto = "#{email}?bcc=#{Setting.email_dropbox[:address]}"
    else
      mailto = email
    end
    if block_given?
      link_to("mailto:#{mailto}", :title => email) do
        yield
      end
    else
      link_to(h(name), "mailto:#{mailto}", :title => email)
    end
  end

  #----------------------------------------------------------------------------
  def jumpbox(current)
    tabs = [ :contacts, :accounts, :contact_groups, :events ]
    current = tabs.first unless tabs.include?(current)
    tabs.map do |tab|
      link_to_function(t("tab_#{tab}"), "crm.jumper('#{tab}')", "html-data" => tab, :class => (tab == current ? 'selected' : ''))
    end.join(" | ").html_safe
  end

  #----------------------------------------------------------------------------
  def styles_for(*models)
    render :partial => "shared/inline_styles", :locals => { :models => models }
  end

  #----------------------------------------------------------------------------
  def hidden;    { :style => "display:none;"       }; end
  def exposed;   { :style => "display:block;"      }; end
  def exposed_inline;   { :style => "display:inline;"      }; end
  def invisible; { :style => "visibility:hidden;"  }; end
  def visible;   { :style => "visibility:visible;" }; end

  #----------------------------------------------------------------------------
  def one_submit_only(form='')
    { :onsubmit => "$('#'+this.id+' input[type=submit]').prop('disabled', true)".html_safe }
  end

  #----------------------------------------------------------------------------
  def hidden_if(you_ask)
    you_ask ? hidden : exposed
  end
  
  #----------------------------------------------------------------------------
  def hidden_inline_if(you_ask)
    you_ask ? hidden : exposed_inline
  end

  #----------------------------------------------------------------------------
  def invisible_if(you_ask)
    you_ask ? invisible : visible
  end

  #----------------------------------------------------------------------------
  def confirm_delete(model, params = {})
    question = %(<span class="warn">#{t(:confirm_delete, model.class.to_s.downcase)}</span>).html_safe
    yes = link_to(t(:yes_button), params[:url] || model, :method => :delete)
    no = link_to_function(t(:no_button), "$('#menu').html($('#confirm').html());")
    text = "$('#confirm').html( $('#menu').html() );\n"
    text << "$('#menu').html('#{question} #{yes} : #{no}');"
    text.html_safe
  end

  #----------------------------------------------------------------------------
  def spacer(width = 10)
    image_tag "1x1.gif", :width => width, :height => 1, :alt => nil
  end

  # Reresh sidebar using the action view within the current controller.
  #----------------------------------------------------------------------------
  def refresh_sidebar(action = nil, shake = nil)
    refresh_sidebar_for(controller.controller_name, action, shake)
  end

  # Refresh sidebar using the action view within an arbitrary controller.
  #----------------------------------------------------------------------------
  def refresh_sidebar_for(view, action = nil, shake = nil)
    text = ""
    text << "$('#sidebar').html('#{ j render(:partial => "layouts/sidebar", :locals => { :view => view, :action => action }) }');"
    text << "$('##{j shake.to_s}').effect('shake', { duration:200, distance: 3 });" if shake
    text.html_safe
  end

  # Display web presence mini-icons for Contact or Lead.
  #----------------------------------------------------------------------------
  def web_presence_icons(person)
    [ :blog, :linkedin, :facebook, :twitter, :skype ].map do |site|
      url = person.send(site)
      unless url.blank?
        if site == :skype then
          url = "callto:" << url
        else
          url = "http://" << url unless url.match(/^https?:\/\//)
        end
        link_to(image_tag("#{site}.gif", :size => "15x15"), url, :"data-popup" => true, :title => t(:open_in_window, url))
      end
    end.compact.join("\n").html_safe
  end

  # Ajax helper to refresh current index page once the user selects an option.
  #----------------------------------------------------------------------------
  def redraw(option, value, url = send("redraw_#{controller.controller_name}_path"))
    if value.is_a?(Array)
      param, value = value.first, value.last
    end
    %Q{
      if ($('##{option}').html() != '#{value}') {
        $('##{option}').html('#{value}');
        $('#loading').show();
        $.post('#{url}', {#{option}: '#{param || value}'}, function () {
          $('#loading').hide();
        });
      }
    }
  end

  #----------------------------------------------------------------------------
  def options_menu_item(option, key, url = send("redraw_#{controller.controller_name}_path"))
    name = t("option_#{key}")
    "{ name: \"#{name.titleize}\", on_select: function() {" +
    %Q{
      if ($('##{option}').html() != '#{name}') {
        $('##{option}').html('#{name}');
        $('#loading').show();
        $.get('#{url}', {#{option}: '#{key}', query: $('#query').val()}, function () {
          $('#loading').hide();
        });
      }
    } + "}}"
  end

  # Ajax helper to pass browser timezone offset to the server.
  #----------------------------------------------------------------------------
  def get_browser_timezone_offset
    unless session[:timezone_offset]
      "$.get('#{timezone_path}', {offset: (new Date()).getTimezoneOffset()});"
    end
  end

  # Entities can have associated avatars or gravatars. Only calls Gravatar
  # in production env. Gravatar won't serve default images if they are not
  # publically available: http://en.gravatar.com/site/implement/images
  #----------------------------------------------------------------------------
  def avatar_for(model, args = {})
    args = { :class => 'gravatar', :size => :large }.merge(args)

    if model.respond_to?(:avatar) and model.avatar.present?
      image_tag(model.avatar.image.url(args[:size]), args)
    else
      args = Avatar.size_from_style!(args) # convert size format :large => '75x75'
      gravatar_image_tag(model.email, args)
    end

  end

  # Returns default permissions intro.
  #----------------------------------------------------------------------------
  def get_default_permissions_intro(access, text)
    case access
      when "Private" then t(:permissions_intro_private, text)
      when "Public"  then t(:permissions_intro_public,  text)
      when "Shared"  then t(:permissions_intro_shared,  text)
    end
  end

  # Render a text field that is part of compound address.
  #----------------------------------------------------------------------------
  def address_field(form, object, attribute, extra_styles)
    hint = "#{t(attribute)}..."
    if object.send(attribute).blank?
      form.text_field(attribute,
        :style   => "margin-top: 6px; #{extra_styles}",
        :placeholder => hint
      )
    else
      form.text_field(attribute,
        :style   => "margin-top: 6px; #{extra_styles}",
        :placeholder => hint
      )
    end
  end

  # Return true if:
  #   - it's an Ajax request made from the asset landing page (i.e. create opportunity
  #     from a contact landing page) OR
  #   - we're actually showing asset landing page.
  #----------------------------------------------------------------------------
  def shown_on_landing_page?
    !!((request.xhr? && request.referer =~ %r|/\w+/\d+|) ||
       (!request.xhr? && request.fullpath =~ %r|/\w+/\d+|))
  end

  # Helper to display links to supported data export formats.
  #----------------------------------------------------------------------------
  def links_to_export(action=:index)
    token = current_user.single_access_token
    query = params[:query] ? params[:query] : session[:"#{params[:controller]}_current_query"]
    url_params = {:action => action}
    url_params.merge!(:id => params[:id]) unless params[:id].blank?
    url_params.merge!(:query => query) unless query.blank?
    url_params.merge!(:q => params[:q]) unless params[:q].blank?
    url_params.merge!(:view => @view) unless @view.blank? # tasks
    url_params.merge!(:id => params[:id]) unless params[:id].blank?

    exports = %w(xls csv).map do |format|
      link_to(format.upcase, url_params.merge(:format => format), :title => I18n.t(:"to_#{format}")) unless action.to_s == "show"
    end

    feeds = %w(rss atom).map do |format|
      link_to(format.upcase, url_params.merge(:format => format, :authentication_credentials => token), :title => I18n.t(:"to_#{format}"))
    end

    links = %W(perm).map do |format|
      link_to(format.upcase, url_params, :title => I18n.t(:"to_#{format}"))
    end
   
    emails_to_clipboard = %W(email_clip).map do |format|
      if params[:controller] == "contact_groups"
        link_to("EMAIL &#8250; CLIPBOARD".html_safe, url_params.merge(:format => :js, :action => :email, :query => @current_query), :remote => true) 
      end
    end
    
    emails = %W(email).map do |format|
      if params[:controller] == "contact_groups"
        group_emails = @contact_groups.collect{|cg| cg.email_addresses}.join(", ") if @contact_groups.any?
        mail_to(group_emails, format.upcase)
      end
    end
    
    (exports + feeds + links + emails + emails_to_clipboard).compact.join(' | ')
  end

  def user_options
    User.all.map {|u| [u.full_name, u.id]}
  end

  def group_options
    Group.all.map {|g| [g.name, g.id]}
  end

  def list_of_entities
    ENTITIES
  end

  def entity_filter_checkbox(name, value, count)
    checked = (session["#{controller_name}_filter"].present? ? session["#{controller_name}_filter"].split(",").include?(value.to_s) : count.to_i > 0)
    url = url_for(:action => :filter)
    onclick = %Q{
      var query = $('#query').val(),
          values = [];
      $('input[name=&quot;#{name}[]&quot;]').filter(':checked').each(function () {
        values.push(this.value);
      });
      $('#loading').show();
      $.post('#{url}', {#{name}: values.join(','), query: query}, function () {
        $('#loading').hide();
      });
    }.html_safe
    check_box_tag("#{name}[]", value, checked, :id => value, :onclick => onclick)
  end

  # Create a column in the 'asset_attributes' table.
  #----------------------------------------------------------------------------
  def col(title, value, last = false, email = false)
    # Parse and format urls as links.
    fmt_value = (value.to_s || "").gsub("\n", "<br />")
    fmt_value = if email
        link_to_email(fmt_value)
      else
        fmt_value.gsub(/((http|ftp|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:\/\+#]*[\w\-\@?^=%&amp;\/\+#])?)/, "<a href=\"\\1\">\\1</a>")
      end
    %Q^<th#{last ? " class=\"last\"" : ""}>#{title}:</th>
  <td#{last ? " class=\"last\"" : ""}>#{fmt_value}</td>^.html_safe
  end

  #----------------------------------------------------------------------------
  # Combines the 'subtitle' helper with the small info text on the same line.
  def section_title(id, hidden = true, text = nil, info_text = nil)
    text = id.to_s.split("_").last.capitalize if text == nil
    content_tag("div", :class => "subtitle show_attributes") do
      content = link_to("<small>#{ hidden ? "&#9658;" : "&#9660;" }</small> #{text}".html_safe,
        url_for(:controller => :home, :action => :toggle, :id => id),
        :remote  => true,
        :onclick => "crm.flip_subtitle(this)"
      )
      content << content_tag("small", info_text.to_s, {:class => "subtitle_inline_info", :id => "#{id}_intro", :style => hidden ? "" : "display:none;"})
    end
  end
  
  #----------------------------------------------------------------------------
  # Combines the 'subtitle' helper with the small info text on the same line.
  def event_title(id, hidden = true, text = nil, info_text = nil)
    text = id.to_s.split("_").last.capitalize if text == nil
    content_tag("div", :class => "subtitle show_attributes", :style => "margin-top:0px;height:13px") do
      content = link_to("<small>#{ hidden ? "&#9658;" : "&#9660;" }</small> #{text}".html_safe,
        url_for(:controller => :home, :action => :toggle, :id => id),
        :remote  => true,
        :onclick => "crm.flip_subtitle2(this)"
      )
      content << content_tag("small", info_text.to_s, {:class => "subtitle_inline_info", :id => "#{id}_intro", :style => hidden ? "" : "display:none;"})
    end
  end
  

  #----------------------------------------------------------------------------
  # Return name of current view
  def current_view_name
    controller = (params['action'] == "move_contact" || params['action'] == "assign_contact") ? "contacts" : params['controller']
    action = (params['action'] == 'show' || params['action'] == 'redraw_show') ? 'show' : 'index' # create update redraw filter index actions all use index view

    current_user.pref[:"#{controller}_#{action}_view"]
  end

  #----------------------------------------------------------------------------
  # Get template in current context with current view name
  def template_for_current_view
    controller = (params['action'] == "move_contact" || params['action'] == "assign_contact") ? "contacts" : params['controller']
    action = (params['action'] == 'show' || params['action'] == 'redraw_show') ? 'show' : 'index' # create update redraw filter index actions all use index view

    template = FatFreeCRM::ViewFactory.template_for_current_view(:controller => controller, :action => action, :name => current_view_name)
    template
  end

  #----------------------------------------------------------------------------
  # Generate buttons for available views given the current context
  def view_buttons
    controller = params['controller']
    action = (params['action'] == 'show') ? 'show' : 'index' # create update redraw filter index actions all use index view
    views = FatFreeCRM::ViewFactory.views_for(:controller => controller, :action => action)
    return nil unless views.size > 1
    content_tag :ul, :class => 'format-buttons' do
      views.collect do |view|
        classes = if (current_view_name == view.name) or (current_view_name == nil and view.template == nil) # nil indicates default template.
            "#{view.name}-button active"
          else
            "#{view.name}-button"
          end
        content_tag(:li) do
          url = (action == "index") ? send("redraw_#{controller}_path") : send("#{controller.singularize}_path")
          link_to('#', :title => t(view.name, :default => view.title), :"data-view" => view.name, :"data-url" => url, :"data-context" => action, :class => classes) do
            icon = view.icon || 'fa-bars'
            content_tag(:i, nil, class: "fa #{icon}")
          end
        end
      end.join('').html_safe
    end
  end
  
  def link_to_confirm_delete(model)
    link_to(t(:yes_button),
      url_for(model),
      :method  => :delete,
      :remote  => true,
      :onclick => "$('\##{dom_id(model)}').effect(\"highlight\");".html_safe 
    )
  end
  
  def indefinite_article(params_word)
      %w(a e i o u).include?(params_word[0].downcase) ? "an" : "a"
  end

  #----------------------------------------------------------------------------
  # Generate the html for $.timeago function
  # <span class="timeago" datetime="2008-07-17T09:24:17Z">July 17, 2008</span>
  def timeago(time, options = {})
    options[:class] ||= "timeago"
    content_tag(:span, time.to_s, options.merge( title: time.getutc.iso8601)) if time
  end

  #----------------------------------------------------------------------------
  # Translate List name to FontAwesome icon text
  def get_icon(name)
    case name
      when "tasks" then "fa-check-square-o"
      when "campaigns" then "fa-bar-chart-o"
      when "leads" then "fa-tasks"
      when "accounts" then "fa-users"
      when "contacts" then "fa-user"
      when "opportunities" then "fa-money"
      when "team" then "fa-globe"
    end
  end

  #----------------------------------------------------------------------------
  # Ajaxification FTW!
  # e.g. collection = Opportunity.my.scope
  #         options = { renderer: {...} , params: {...}
  def paginate(options = {})
    collection = options.delete(:collection)
    options = { renderer: RemoteLinkPaginationHelper::LinkRenderer }.merge(options)
    will_paginate(collection, options)
  end

end
