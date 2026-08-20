class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.references :tournament, null: false, foreign_key: true
      t.integer :round, null: false
      t.integer :position, null: false
      t.string :status, null: false, default: "pending"
      t.references :player1, foreign_key: { to_table: :participants }
      t.references :player2, foreign_key: { to_table: :participants }
      t.references :winner, foreign_key: { to_table: :participants }

      t.timestamps
    end
    add_index :matches, [ :tournament_id, :round, :position ], unique: true, name: "index_matches_on_tournament_round_position"
  end
end
