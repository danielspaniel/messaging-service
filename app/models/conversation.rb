class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy
  has_many :conversation_participants, dependent: :destroy
  has_many :participants, through: :conversation_participants
  
  validates :message_type, presence: true, inclusion: { in: %w[sms mms email] }
  
  # Find or create a conversation based on participants and message type
  # participants can be an array of identifiers or individual from/to params
  def self.find_or_create_for_participants(participants_or_from, to_or_message_type = nil, message_type = nil)
    # Handle both array and individual parameter formats
    if participants_or_from.is_a?(Array)
      participant_identifiers = participants_or_from.map(&:to_s).compact.sort
      # If second param is message_type when first is array
      msg_type = to_or_message_type
      raise ArgumentError, "message_type is required when using array format" unless msg_type
    else
      # Legacy format: find_or_create_for_participants(from, to, message_type)
      # 2-param format is no longer supported - message_type is always required
      from = participants_or_from.to_s if participants_or_from
      
      if message_type.present?
        # 3-param format: (from, to, message_type)
        to = to_or_message_type.to_s if to_or_message_type
        msg_type = message_type
      else
        # 2-param format: treat second param as 'to', message_type is required
        to = to_or_message_type.to_s if to_or_message_type
        raise ArgumentError, "message_type is required when using 2-param format"
      end
      
      participant_identifiers = [from, to].compact.sort
    end
    
    # Find or create participant records
    participant_records = participant_identifiers.map do |identifier|
      Participant.find_or_create_by_identifier(identifier)
    end
    
    # Find conversations that have exactly these participants AND the same message type
    # Use a more efficient query that checks both participant count and message type
    conversation = Conversation.joins(:conversation_participants)
      .where(message_type: msg_type)
      .where(conversation_participants: { participant: participant_records })
      .group('conversations.id')
      .having('COUNT(conversation_participants.id) = ?', participant_records.length)
      .includes(:participants)
      .find { |conv| conv.participants.pluck(:identifier).sort == participant_identifiers }
    
    # Create new conversation if none exists
    if conversation.nil?
      conversation = Conversation.create!(message_type: msg_type)
      participant_records.each do |participant|
        conversation.conversation_participants.create!(participant: participant)
      end
    end
    
    conversation
  end
  
  def other_participant(current_participant)
    # Get participant identifiers
    participant_identifiers = participants.pluck(:identifier)
    
    # Return nil if current_participant is not in this conversation
    return nil unless participant_identifiers.include?(current_participant.to_s)
    
    # Find the other participant identifier
    other_identifier = participant_identifiers.find { |p| p != current_participant.to_s }
    
    # Return the other participant record
    participants.find_by(identifier: other_identifier)
  end
end
