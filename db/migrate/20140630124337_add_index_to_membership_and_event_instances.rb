class AddIndexToMembershipAndEventInstances < ActiveRecord::Migration
  def change
    add_index :event_instances, :event_id, :name => "event_instances_index_on_event_id"
    add_index :memberships, :contact_id, :name => "memberships_index_on_contact_id"
  end
end
