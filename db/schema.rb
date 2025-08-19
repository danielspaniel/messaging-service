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

ActiveRecord::Schema[8.0].define(version: 2025_08_19_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "conversation_participants", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "participant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "participant_id"], name: "unique_conversation_participant", unique: true
    t.index ["participant_id"], name: "index_conversation_participants_on_participant_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "message_type", default: "sms", null: false
    t.index ["message_type"], name: "index_conversations_on_message_type"
  end

  create_table "message_deliveries", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "recipient_id", null: false
    t.string "status", default: "pending", null: false
    t.string "provider_message_id"
    t.datetime "sent_at"
    t.datetime "failed_at"
    t.text "failure_reason"
    t.integer "retry_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "status"], name: "index_message_deliveries_on_message_id_and_status"
    t.index ["message_id"], name: "index_message_deliveries_on_message_id"
    t.index ["provider_message_id"], name: "index_message_deliveries_on_provider_message_id"
    t.index ["recipient_id"], name: "index_message_deliveries_on_recipient_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "sender_id", null: false
    t.string "message_type", null: false
    t.text "body", null: false
    t.text "attachments"
    t.datetime "timestamp", null: false
    t.string "provider_message_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "pending", null: false
    t.datetime "queued_at"
    t.datetime "sent_at"
    t.datetime "failed_at"
    t.integer "retry_count", default: 0
    t.text "failure_reason"
    t.index ["conversation_id", "sender_id", "timestamp"], name: "index_messages_unique_per_sender"
    t.index ["conversation_id", "timestamp"], name: "index_messages_on_conversation_id_and_timestamp"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["provider_message_id"], name: "index_messages_on_provider_message_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
    t.index ["status", "created_at"], name: "index_messages_on_status_and_created_at"
    t.index ["status"], name: "index_messages_on_status"
    t.index ["timestamp"], name: "index_messages_on_timestamp"
  end

  create_table "participants", force: :cascade do |t|
    t.string "identifier", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier"], name: "index_participants_on_identifier", unique: true
  end

  create_table "solid_queue_blocked_jobs", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["concurrency_key"], name: "index_solid_queue_blocked_jobs_on_concurrency_key"
    t.index ["job_id"], name: "index_solid_queue_blocked_jobs_on_job_id"
  end

  create_table "solid_queue_claimed_jobs", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "process_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_jobs_on_job_id"
  end

  create_table "solid_queue_failed_jobs", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "exception_class"
    t.text "exception_message"
    t.text "backtrace"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_jobs_on_job_id"
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "active_job_id"
    t.index ["active", "scheduled_at", "priority", "created_at"], name: "index_solid_queue_jobs_for_execution"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["concurrency_key", "finished_at"], name: "index_solid_queue_jobs_on_concurrency_key_and_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_on_queue_name_and_finished_at"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind"
    t.datetime "last_heartbeat_at"
    t.string "supervisor_id"
    t.integer "pid"
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "solid_queue_ready_jobs", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_jobs_on_job_id"
    t.index ["queue_name", "priority", "created_at"], name: "index_solid_queue_ready_jobs_for_dispatch"
  end

  create_table "solid_queue_scheduled_jobs", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_jobs_on_job_id"
    t.index ["scheduled_at"], name: "index_solid_queue_scheduled_jobs_on_scheduled_at"
  end

  add_foreign_key "conversation_participants", "conversations"
  add_foreign_key "conversation_participants", "participants"
  add_foreign_key "message_deliveries", "messages"
  add_foreign_key "message_deliveries", "participants", column: "recipient_id"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "participants", column: "sender_id"
  add_foreign_key "solid_queue_blocked_jobs", "solid_queue_jobs", column: "job_id"
  add_foreign_key "solid_queue_claimed_jobs", "solid_queue_jobs", column: "job_id"
  add_foreign_key "solid_queue_failed_jobs", "solid_queue_jobs", column: "job_id"
  add_foreign_key "solid_queue_ready_jobs", "solid_queue_jobs", column: "job_id"
  add_foreign_key "solid_queue_scheduled_jobs", "solid_queue_jobs", column: "job_id"
end
