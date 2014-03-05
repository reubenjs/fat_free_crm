class AddInactiveToEntities < ActiveRecord::Migration
  def self.up
    add_column :accounts, :inactive, :boolean, :default => false
    add_column :contacts, :inactive, :boolean, :default => false
    add_column :contact_groups, :inactive, :boolean, :default => false
    add_column :events, :inactive, :boolean, :default => false
  
  end

  def self.down
    remove_column :accounts, :inactive
    remove_column :contacts, :inactive
    remove_column :contact_groups, :inactive
    remove_column :events, :inactive
    
  end
end
