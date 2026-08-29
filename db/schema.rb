# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_25_141642) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "player1_id"
    t.integer "player2_id"
    t.integer "position", null: false
    t.integer "round", null: false
    t.string "status", default: "pending", null: false
    t.integer "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.integer "winner_id"
    t.index ["player1_id"], name: "index_matches_on_player1_id"
    t.index ["player2_id"], name: "index_matches_on_player2_id"
    t.index ["tournament_id", "round", "position"], name: "index_matches_on_tournament_round_position", unique: true
    t.index ["tournament_id"], name: "index_matches_on_tournament_id"
    t.index ["winner_id"], name: "index_matches_on_winner_id"
  end

  create_table "participants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.integer "seed"
    t.integer "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["tournament_id", "user_id"], name: "index_participants_on_tournament_id_and_user_id", unique: true
    t.index ["tournament_id"], name: "index_participants_on_tournament_id"
    t.index ["user_id"], name: "index_participants_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.integer "chosen_winner_id", null: false
    t.datetime "created_at", null: false
    t.integer "match_id", null: false
    t.integer "reporter_id", null: false
    t.datetime "updated_at", null: false
    t.index ["chosen_winner_id"], name: "index_reports_on_chosen_winner_id"
    t.index ["match_id", "reporter_id"], name: "index_reports_on_match_and_reporter", unique: true
    t.index ["match_id"], name: "index_reports_on_match_id"
    t.index ["reporter_id"], name: "index_reports_on_reporter_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.string "name", null: false
    t.datetime "started_at"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_tournaments_on_creator_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.boolean "day2_attending"
    t.boolean "day3_attending"
    t.string "email_address", null: false
    t.string "name", default: "", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "matches", "participants", column: "player1_id"
  add_foreign_key "matches", "participants", column: "player2_id"
  add_foreign_key "matches", "participants", column: "winner_id"
  add_foreign_key "matches", "tournaments"
  add_foreign_key "participants", "tournaments"
  add_foreign_key "participants", "users"
  add_foreign_key "reports", "matches"
  add_foreign_key "reports", "participants", column: "chosen_winner_id"
  add_foreign_key "reports", "participants", column: "reporter_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "tournaments", "users", column: "creator_id"
end
