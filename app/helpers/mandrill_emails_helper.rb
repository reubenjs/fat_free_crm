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

module MandrillEmailsHelper

  # Sidebar checkbox control for filtering accounts by category.
  #----------------------------------------------------------------------------
  def mandrill_email_category_checbox(category, count)
    checked = (session[:mandrill_emails_filter] ? session[:mandrill_emails_filter].split(",").include?(category.to_s) : count.to_i > 0)
    url = url_for(:action => :filter)
    onclick = %Q{
      $('#loading').show();
      $.post('#{url}', {category: this.value, checked: this.checked}, function () {
        $('#loading').hide();
      });
    }.html_safe
    check_box_tag("category[]", category, checked, :id => category, :onclick => onclick)
  end
end
