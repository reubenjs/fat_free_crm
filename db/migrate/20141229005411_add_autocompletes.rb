class AddAutocompletes < ActiveRecord::Migration
  def up
    create_table :autocompletes, :force => true do |t|
      t.string :name
      t.text :terms, :limit => 16.megabytes - 1 
    end
  end

  def down
    drop_table :autocompletes
  end
end
