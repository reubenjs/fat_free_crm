class ChangeContactSaausuUidType < ActiveRecord::Migration
  def up
    change_column :contacts, :saasu_uid, :string
  end

  def down
    change_column :contacts, :saasu_uid, :integer
  end
end
