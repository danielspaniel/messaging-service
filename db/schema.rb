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

ActiveRecord::Schema[8.0].define(version: 2024_12_01_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "conversations", force: :cascade do |t|
    t.text "participants", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["participants"], name: "index_conversations_on_participants"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "from", null: false
    t.string "to", null: false
    t.string "message_type", null: false
    t.text "body", null: false
    t.text "attachments"
    t.datetime "timestamp", null: false
    t.string "direction", null: false
    t.string "messaging_provider_id"
    t.string "xillio_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "timestamp"], name: "index_messages_on_conversation_id_and_timestamp"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["timestamp"], name: "index_messages_on_timestamp"
  end

  add_foreign_key "messages", "conversations"
end
