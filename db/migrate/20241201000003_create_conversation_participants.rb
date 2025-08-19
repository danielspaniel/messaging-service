class CreateConversationParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_participants do |t|
      t.bigint :conversation_id, null: false
      t.bigint :participant_id, null: false
      t.timestamps
    end
    
    add_foreign_key :conversation_participants, :conversations
    add_foreign_key :conversation_participants, :participants
    add_index :conversation_participants, [:conversation_id, :participant_id], 
              unique: true, name: 'unique_conversation_participant'
    add_index :conversation_participants, :participant_id
  end
end
