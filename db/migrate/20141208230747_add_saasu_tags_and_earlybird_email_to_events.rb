class AddSaasuTagsAndEarlybirdEmailToEvents < ActiveRecord::Migration
  def change
    add_column :events, :saasu_tags, :string
    
    add_column :events, :end_earlybird_email, :text
    add_column :events, :end_earlybird_email_from_name, :string
    add_column :events, :end_earlybird_email_from_address, :string
    add_column :events, :end_earlybird_email_subject, :string
    add_column :events, :end_earlybird_email_bcc, :string
  end
end
