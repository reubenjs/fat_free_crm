class AddPreferredNameToContacts < ActiveRecord::Migration
  def change
    add_column :contacts, :preferred_name, :string
  end
end
