class AddConfirmationEmailToEvents < ActiveRecord::Migration
  def change
    add_column :events, :confirmation_email, :text
    add_column :events, :confirmation_email_from_name, :string
    add_column :events, :confirmation_email_from_address, :string
    add_column :events, :confirmation_email_subject, :string
    add_column :events, :confirmation_email_bcc, :string
  end
end
