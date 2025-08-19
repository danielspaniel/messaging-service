class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :participants }

      t.string :message_type, null: false # sms, mms, email
      t.text :body, null: false
      t.text :attachments # serialized array
      t.datetime :timestamp, null: false
      t.string :provider_message_id # unified provider ID for all message types
      
      t.string :status, default: 'pending', null: false
      t.datetime :queued_at
      t.datetime :sent_at
      t.datetime :failed_at
      t.integer :retry_count, default: 0
      t.text :failure_reason
      
      t.timestamps
    end
    
    # Essential indexes only
    
    # Critical: conversation messages ordered by timestamp (conversation.messages.ordered)
    add_index :messages, [:conversation_id, :timestamp]
    
    # Webhook lookups: find message by provider ID
    add_index :messages, :provider_message_id
    
    # Job processing: find messages by status (pending, failed, etc.)
    add_index :messages, :status
    
    # Note: conversation_id and sender_id indexes are automatically created by t.references
  end
end
