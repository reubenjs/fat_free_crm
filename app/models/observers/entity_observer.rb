# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class EntityObserver < ActiveRecord::Observer
  observe :account, :contact, :lead, :opportunity, :task

  def after_create(item)
    send_notification_to_assignee(item) if current_user != item.assignee
  end

  def after_update(item)
    if item.assigned_to_changed? && item.assignee != current_user
      send_notification_to_assignee(item)
    end
  end

  private

  def send_notification_to_assignee(item)
    #UserMailer.assigned_entity_notification(item, current_user).deliver if item.assignee.present? && current_user.present?
    UserMailer.delay.assigned_entity_notification(item, (current_user.present? ? current_user : User.find(1)) ) if item.assignee.present?
  end

  def current_user
    # this deals with whodunnit inconsistencies, where in some cases it's set to a user's id and others the user object itself
    user_id_or_user = PaperTrail.whodunnit
    if user_id_or_user.is_a?(User)
      user_id_or_user
    elsif user_id_or_user.is_a?(String)
      User.find_by_id(user_id_or_user.to_i)
    end
  end
end
