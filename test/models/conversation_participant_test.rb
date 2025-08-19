require 'test_helper'

class ConversationParticipantTest < ActiveSupport::TestCase
  def test_should_belong_to_conversation_and_participant
    conversation_participant = ConversationParticipant.new
    assert_not conversation_participant.valid?
    assert_includes conversation_participant.errors[:conversation], "must exist"
    assert_includes conversation_participant.errors[:participant], "must exist"
  end
  
  def test_should_validate_uniqueness_of_conversation_and_participant
    conversation = create(:conversation, participant_identifiers: ['user1', 'user2'])
    participant = conversation.participants.first
    
    # Try to create duplicate association
    duplicate = ConversationParticipant.new(
      conversation: conversation,
      participant: participant
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:conversation_id], "has already been taken"
  end
  
  def test_associations
    conversation_participant = create(:conversation_participant)
    
    assert conversation_participant.conversation.present?
    assert conversation_participant.participant.present?
  end
end
