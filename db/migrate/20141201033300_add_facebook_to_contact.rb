class AddFacebookToContact < ActiveRecord::Migration
  def change
    add_column :contacts, :facebook_uid, :string
    add_column :contacts, :facebook_token, :string
  end
end
