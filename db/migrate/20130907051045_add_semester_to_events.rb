class AddSemesterToEvents < ActiveRecord::Migration
  def change
    add_column :events, :semester, :string
  end
end
