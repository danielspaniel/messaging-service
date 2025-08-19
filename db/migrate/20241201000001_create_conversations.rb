class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.string :message_type, null: false
      t.timestamps
    end
    
    # Index for querying conversations by message type
    add_index :conversations, :message_type
  end
end
