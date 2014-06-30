class AddInactiveIndexes < ActiveRecord::Migration
  def change
    add_index :contacts, :inactive, :name => "index_contacts_inactive"
    add_index :contacts, :first_name, :name => "index_contacts_on_first_name"
    add_index :contacts, :last_name, :name => "index_contacts_on_last_name"
    add_index :contacts, [:inactive, :assigned_to], :name =>"index_contacts_on_inactive_assigned_to"
    add_index :accounts, :inactive, :name => "index_accounts_inactive"
    add_index :contact_groups, :inactive, :name => "index_contact_groups_inactive"
    add_index :events, :inactive, :name => "index_events_inactive"
  end
end
