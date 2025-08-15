require "test_helper"

class MessageTest < ActiveSupport::TestCase
  def test_belongs_to_conversation
    message = create(:message)
    assert_respond_to message, :conversation
    assert_instance_of Conversation, message.conversation
  end

  def test_validates_presence_of_required_fields
    message = Message.new
    assert_not message.valid?
    
    assert_includes message.errors[:from], "can't be blank"
    assert_includes message.errors[:to], "can't be blank"
    assert_includes message.errors[:message_type], "can't be blank"
    assert_includes message.errors[:body], "can't be blank"
    assert_includes message.errors[:timestamp], "can't be blank"
    assert_includes message.errors[:direction], "can't be blank"
  end

  def test_validates_message_type_inclusion
    conversation = create(:conversation)
    message = Message.new(
      conversation: conversation,
      from: '+12345678901',
      to: '+19876543210',
      message_type: 'invalid',
      body: 'Test message',
      timestamp: Time.current,
      direction: 'outbound'
    )
    assert_not message.valid?
    assert_includes message.errors[:message_type], "is not included in the list"
  end

  def test_validates_direction_inclusion
    conversation = create(:conversation)
    message = Message.new(
      conversation: conversation,
      from: '+12345678901',
      to: '+19876543210',
      message_type: 'sms',
      body: 'Test message',
      timestamp: Time.current,
      direction: 'invalid'
    )
    assert_not message.valid?
    assert_includes message.errors[:direction], "is not included in the list"
  end

  def test_serializes_attachments_as_array
    message = create(:message, :with_attachments)
    assert message.attachments.is_a?(Array)
    assert_equal 2, message.attachments.size
  end

  def test_ordered_scope_orders_by_timestamp
    old_message = create(:message, timestamp: 2.hours.ago)
    new_message = create(:message, timestamp: 1.hour.ago)
    
    ordered_messages = Message.ordered
    assert_equal old_message, ordered_messages.first
    assert_equal new_message, ordered_messages.last
  end

  def test_inbound_scope_returns_only_inbound_messages
    inbound_message = create(:message, :inbound)
    outbound_message = create(:message, direction: 'outbound')
    
    inbound_messages = Message.inbound
    assert_includes inbound_messages, inbound_message
    assert_not_includes inbound_messages, outbound_message
  end

  def test_outbound_scope_returns_only_outbound_messages
    inbound_message = create(:message, :inbound)
    outbound_message = create(:message, direction: 'outbound')
    
    outbound_messages = Message.outbound
    assert_includes outbound_messages, outbound_message
    assert_not_includes outbound_messages, inbound_message
  end

  def test_create_with_conversation_creates_new_conversation_and_message
    attributes = {
      from: '+12016661234',
      to: '+18045551234',
      message_type: 'sms',
      body: 'Test message',
      timestamp: Time.current,
      direction: 'outbound'
    }
    
    assert_difference 'Conversation.count', 1 do
      assert_difference 'Message.count', 1 do
        Message.create_with_conversation!(attributes)
      end
    end
  end

  def test_create_with_conversation_associates_message_with_new_conversation
    attributes = {
      from: '+12016661234',
      to: '+18045551234',
      message_type: 'sms',
      body: 'Test message',
      timestamp: Time.current,
      direction: 'outbound'
    }
    
    message = Message.create_with_conversation!(attributes)
    assert_includes message.conversation.participants, attributes[:from]
    assert_includes message.conversation.participants, attributes[:to]
  end

  def test_create_with_conversation_uses_existing_conversation
    attributes = {
      from: '+12016661234',
      to: '+18045551234',
      message_type: 'sms',
      body: 'Test message',
      timestamp: Time.current,
      direction: 'outbound'
    }
    
    existing_conversation = Conversation.find_or_create_for_participants(
      attributes[:from], attributes[:to]
    )
    
    assert_difference 'Message.count', 1 do
      assert_no_difference 'Conversation.count' do
        message = Message.create_with_conversation!(attributes)
        assert_equal existing_conversation, message.conversation
      end
    end
  end

  def test_provider_message_id_for_sms_mms_returns_messaging_provider_id
    message = create(:message, messaging_provider_id: 'sms_123')
    assert_equal 'sms_123', message.provider_message_id
  end

  def test_provider_message_id_for_email_returns_xillio_id
    message = create(:message, :email, xillio_id: 'email_456')
    assert_equal 'email_456', message.provider_message_id
  end

  def test_can_create_sms_messages
    message = create(:message, message_type: 'sms')
    assert message.valid?
    assert_equal 'sms', message.message_type
  end

  def test_can_create_mms_messages
    message = create(:message, :mms)
    assert message.valid?
    assert_equal 'mms', message.message_type
    assert_not_empty message.attachments
  end

  def test_can_create_email_messages
    message = create(:message, :email)
    assert message.valid?
    assert_equal 'email', message.message_type
    assert_not_nil message.xillio_id
  end

  def test_can_be_inbound
    message = create(:message, :inbound)
    assert_equal 'inbound', message.direction
  end

  def test_can_be_outbound
    message = create(:message, direction: 'outbound')
    assert_equal 'outbound', message.direction
  end
end