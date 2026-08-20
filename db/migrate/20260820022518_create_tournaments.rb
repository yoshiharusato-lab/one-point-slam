class CreateTournaments < ActiveRecord::Migration[8.1]
  def change
    create_table :tournaments do |t|
      t.string :name, null: false
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "draft"
      t.datetime :started_at

      t.timestamps
    end
  end
end
