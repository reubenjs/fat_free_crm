class AddDiscountAllowedToRegistrations < ActiveRecord::Migration
  def change
    add_column :registrations, :discount_allowed, :boolean, :default => true
  end
end
