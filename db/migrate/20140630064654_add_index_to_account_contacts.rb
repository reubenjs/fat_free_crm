class AddIndexToAccountContacts < ActiveRecord::Migration
  def change
    add_index :account_contacts, :account_id, :name => "index_account_contacts_account_id"
    add_index :account_contacts, :contact_id, :name => "index_account_contacts_contact_id"
  end
end
