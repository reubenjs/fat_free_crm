class AddTshirtToRegisration < ActiveRecord::Migration
  def change
    add_column :registrations, :t_shirt_ordered, :string
    add_column :registrations, :t_shirt_size_ordered, :string
  end
end
