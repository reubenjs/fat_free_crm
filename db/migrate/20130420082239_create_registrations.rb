class CreateRegistrations < ActiveRecord::Migration
  def change
    create_table :registrations do |t|
      t.references :contact
      t.references :event
      t.references :user
      t.string :access, :limit => 8, :default => "Public" # %w(Private Public Shared)
      
      t.boolean :transport_required
      t.text :driver_for
      t.string :can_transport
      t.boolean :first_time
      t.boolean :part_time
      t.text :breakfasts
      t.text :lunches
      t.text :dinners
      t.text :sleeps
      t.string :donate_amount
      t.string :fee
      t.boolean :need_financial_assistance
      t.text :comments
      t.string :payment_method
      t.string :saasu_uid

      t.datetime    :deleted_at
      t.timestamps
    end
    
    #will determine whether registrations are shown for an event
    add_column :events, :has_registrations, :boolean
    
  end
end
