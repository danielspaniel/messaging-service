require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  def test_has_many_messages_with_dependent_destroy
    conversation = create(:conversation)
    message = create(:message, conversation: conversation)
    
    assert_equal 1, conversation.messages.count
    
    conversation.destroy
    assert_equal 0, Message.where(id: message.id).count
  end

  def test_validates_presence_of_participants
    conversation = Conversation.new
    assert_not conversation.valid?
    assert_includes conversation.errors[:participants], "can't be blank"
  end

  def test_serializes_participants_as_array
    conversation = create(:conversation)
    assert conversation.participants.is_a?(Array)
  end

  def test_find_or_create_for_participants_creates_new_conversation_when_none_exists
    from = '+12016661234'
    to = '+18045551234'
    
    assert_difference 'Conversation.count', 1 do
      Conversation.find_or_create_for_participants(from, to)
    end
  end

  def test_find_or_create_for_participants_normalizes_participant_order
    from = '+12016661234'
    to = '+18045551234'
    
    conversation = Conversation.find_or_create_for_participants(from, to)
    assert_equal [from, to].sort, conversation.participants
  end

  def test_find_or_create_for_participants_returns_existing_conversation
    from = '+12016661234'
    to = '+18045551234'
    existing_conversation = create(:conversation, participants: [from, to].sort)
    
    conversation = Conversation.find_or_create_for_participants(from, to)
    assert_equal existing_conversation, conversation
  end

  def test_find_or_create_for_participants_does_not_create_new_when_exists
    from = '+12016661234'
    to = '+18045551234'
    create(:conversation, participants: [from, to].sort)
    
    assert_no_difference 'Conversation.count' do
      Conversation.find_or_create_for_participants(from, to)
    end
  end

  def test_find_or_create_for_participants_finds_regardless_of_order
    from = '+12016661234'
    to = '+18045551234'
    existing_conversation = create(:conversation, participants: [from, to].sort)
    
    conversation = Conversation.find_or_create_for_participants(to, from)
    assert_equal existing_conversation, conversation
  end

  def test_other_participant_returns_correct_participant
    conversation = create(:conversation, participants: ['+12016661234', '+18045551234'])
    
    assert_equal '+18045551234', conversation.other_participant('+12016661234')
    assert_equal '+12016661234', conversation.other_participant('+18045551234')
  end

  def test_other_participant_returns_nil_for_non_participant
    conversation = create(:conversation, participants: ['+12016661234', '+18045551234'])
    assert_nil conversation.other_participant('+15551234567')
  end

  def test_conversation_with_messages_has_associated_messages
    conversation = create(:conversation, :with_messages, message_count: 2)
    assert_equal 2, conversation.messages.count
  end

  def test_destroys_messages_when_conversation_destroyed
    conversation = create(:conversation, :with_messages)
    message_ids = conversation.messages.pluck(:id)
    
    conversation.destroy
    assert_empty Message.where(id: message_ids)
  end
end