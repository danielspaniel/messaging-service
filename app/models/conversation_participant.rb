class ConversationParticipant < ApplicationRecord
  belongs_to :conversation
  belongs_to :participant
  
  validates :conversation_id, uniqueness: { scope: :participant_id }
end
