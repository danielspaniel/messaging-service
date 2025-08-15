class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.text :participants, null: false
      t.timestamps
    end
    
    # Index for finding conversations by participants (critical for find_or_create_for_participants)
    add_index :conversations, :participants
  end
end
