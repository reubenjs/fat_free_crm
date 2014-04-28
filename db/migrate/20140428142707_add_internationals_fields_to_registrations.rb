class AddInternationalsFieldsToRegistrations < ActiveRecord::Migration
  def change
    add_column :registrations, :international_student, :boolean
    add_column :registrations, :requires_sleeping_bag, :boolean
  end
end
