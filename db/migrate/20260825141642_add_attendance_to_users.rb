class AddAttendanceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :day2_attending, :boolean
    add_column :users, :day3_attending, :boolean
  end
end
