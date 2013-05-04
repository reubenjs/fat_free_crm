# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class UserMailer < ActionMailer::Base
  helper :application #for indefinite_articlerize
  
  def password_reset_instructions(user)
    @edit_password_url = edit_password_url(user.perishable_token)
    mail :subject => "Mojo: " + I18n.t(:password_reset_instruction),
         :to => user.email,
         :from => "Mojo <mojo@nt.es.org.au>",
         :date => Time.now
  end

  def assigned_entity_notification(entity, assigner)
    @entity_url = url_for(entity)
    @entity_name = entity.name
    @entity_type = entity.class.name
    @assigner_name = assigner.name
    mail :subject => "Mojo: You have been assigned #{@entity_type} \"#{@entity_name}\"",
         :to => entity.assignee.email,
         :from => "Mojo <mojo@nt.es.org.au>"
  end
  
  def saasu_registration_error(entity, error_text)
    @entity_url = url_for(entity)
    @entity_name = entity.name
    @entity_type = entity.class.name
    @error_text = error_text
    mail :subject => "Mojo Error: Saasu invoice creation failed for #{@entity_type} \"#{@entity_name}\"",
          :to => User.find_by_first_name("Reuben").email,
          :from => "Mojo <mojo@nt.es.org.au>"
          
  end

end

