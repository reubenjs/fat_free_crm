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

# == Schema Information
#
# Table name: account_contacts
#
#  id         :integer         not null, primary key
#  account_id :integer
#  contact_id :integer
#  deleted_at :datetime
#  created_at :datetime
#  updated_at :datetime
#

class Attendance < ActiveRecord::Base
  belongs_to :event_instance
  belongs_to :contact
  validates_presence_of :event_instance_id, :contact_id
  has_one :event, :through => :event_instance
  has_many    :emails, :as => :mediator
  
  acts_as_commentable
  uses_comment_extensions
  has_paper_trail
  
  serialize :subscribed_users, Set
  
  scope :my, lambda {
    #accessible_by(User.current_ability)
    #self.all
  }
  
end
