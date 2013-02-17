class CreateSyncLog < ActiveRecord::Migration
  def up
    create_table :sync_logs do |table|
      table.string :sync_type
      table.string :synced_item
    end
  end

  def down
    drop_table :sync_logs
  end
end
