class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :from, null: false
      t.string :to, null: false
      t.string :message_type, null: false # sms, mms, email
      t.text :body, null: false
      t.text :attachments # serialized array
      t.datetime :timestamp, null: false
      t.string :direction, null: false # inbound, outbound
      t.string :messaging_provider_id # for SMS/MMS
      t.string :xillio_id # for Email
      t.timestamps
    end
    
    # Index for message ordering (used by ordered scope)
    add_index :messages, :timestamp
    
    # Composite index for conversation + timestamp (most common query pattern)
    add_index :messages, [:conversation_id, :timestamp]
  end
end
