class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy
  
  validates :participants, presence: true
  
  # Serialize participants as an array
  serialize :participants, coder: YAML
  
  # Find or create a conversation based on participants
  def self.find_or_create_for_participants(from, to)
    # Handle nil values gracefully - let validation handle empty values
    from = from.to_s if from
    to = to.to_s if to
    
    # Normalize participants to ensure consistent ordering
    normalized_participants = [from, to].compact.sort
    
    # Look for existing conversation with same participants
    conversation = where("participants = ?", normalized_participants.to_yaml).first
    
    # Create new conversation if none exists
    conversation ||= create!(participants: normalized_participants)
    
    conversation
  end
  
  def other_participant(current_participant)
    # Return nil if current_participant is not in this conversation
    return nil unless participants.include?(current_participant)
    
    # Find the other participant
    participants.find { |p| p != current_participant }
  end
end
