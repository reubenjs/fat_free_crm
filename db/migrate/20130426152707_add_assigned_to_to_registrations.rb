class AddAssignedToToRegistrations < ActiveRecord::Migration
  def change
    add_column :registrations, :assigned_to, :integer
  end
end
