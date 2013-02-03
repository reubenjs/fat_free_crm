class AddFromNameToMandrillEmails < ActiveRecord::Migration
  def change
    add_column :mandrill_emails, :from_name, :string
  end
end
