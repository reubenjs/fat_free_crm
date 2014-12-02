class AddSchoolAndReferrerToContacts < ActiveRecord::Migration
  def change
    add_column :contacts, :school, :string
    add_column :contacts, :referral_source, :string
    add_column :contacts, :referral_source_info, :string
  end
end
