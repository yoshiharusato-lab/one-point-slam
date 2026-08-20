class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :match, null: false, foreign_key: true
      t.references :reporter, null: false, foreign_key: { to_table: :participants }
      t.references :chosen_winner, null: false, foreign_key: { to_table: :participants }

      t.timestamps
    end
    add_index :reports, [ :match_id, :reporter_id ], unique: true, name: "index_reports_on_match_and_reporter"
  end
end
