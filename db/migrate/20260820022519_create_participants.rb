class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :display_name
      t.integer :seed

      t.timestamps
    end
    add_index :participants, [ :tournament_id, :user_id ], unique: true
  end
end
