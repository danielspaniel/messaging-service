require "test_helper"

class MessageTest < ActiveSupport::TestCase
  # Association tests are redundant - Rails validations handle this

  def test_validates_presence_of_required_fields
    message = Message.new
    assert_not message.valid?
    
    assert_includes message.errors[:sender], "must exist"
    assert_includes message.errors[:message_type], "can't be blank"
    assert_includes message.errors[:body], "can't be blank"
    assert_includes message.errors[:timestamp], "can't be blank"
    # status has a default value, so no validation error expected
  end

  def test_validates_message_type_inclusion
    sender = create(:participant)
    conversation = create(:conversation, participant_identifiers: [sender.identifier, '+18045551234'])
    message = Message.new(
      conversation: conversation,
      sender: sender,
      message_type: 'invalid',
      body: 'Test message',
      timestamp: Time.current,
      status: 'pending'
    )
    assert_not message.valid?
    assert_includes message.errors[:message_type], "is not included in the list"
  end
  
  def test_validates_status_inclusion
    message = build(:message, status: 'invalid')
    assert_not message.valid?
    assert_includes message.errors[:status], "is not included in the list"
  end
  


  def test_valid_message_types
    %w[sms mms email].each do |type|
      message = build(:message, message_type: type)
      assert message.valid?, "#{type} should be a valid message type"
    end
  end

  def test_serializes_attachments_as_array
    message = create(:message, attachments: ['file1.jpg', 'file2.pdf'])
    assert_instance_of Array, message.attachments
    assert_equal ['file1.jpg', 'file2.pdf'], message.attachments
  end

  def test_orders_messages_by_timestamp
    conversation = create(:conversation)
    
    message1 = create(:message, conversation: conversation, timestamp: 1.hour.ago)
    message2 = create(:message, conversation: conversation, timestamp: 30.minutes.ago)
    message3 = create(:message, conversation: conversation, timestamp: 2.hours.ago)
    
    ordered_messages = conversation.messages.ordered
    assert_equal [message3, message1, message2], ordered_messages.to_a
  end

  def test_provider_message_id_for_sms
    message = create(:message, message_type: 'sms', provider_message_id: 'sms_123')
    assert_equal 'sms_123', message.provider_message_id
  end

  def test_provider_message_id_for_mms
    message = create(:message, message_type: 'mms', provider_message_id: 'mms_456')
    assert_equal 'mms_456', message.provider_message_id
  end

  def test_provider_message_id_for_email
    message = create(:message, message_type: 'email', provider_message_id: 'email_789')
    assert_equal 'email_789', message.provider_message_id
  end

  # Legacy create_with_conversation tests removed - method no longer exists



  def test_sender_returns_participant_object
    sender = create(:participant, identifier: '+12016661234')
    message = create(:message, sender: sender)
    
    assert_equal sender, message.sender
    assert_equal '+12016661234', message.sender.identifier
  end

  # Legacy compatibility test removed - create_with_conversation method no longer exists
  
  def test_status_scopes
    pending_msg = create(:message, status: 'pending')
    queued_msg = create(:message, :queued)
    sent_msg = create(:message, :sent)
    failed_msg = create(:message, :failed)
    
    assert_includes Message.pending, pending_msg
    assert_includes Message.queued, queued_msg
    assert_includes Message.sent, sent_msg
    assert_includes Message.failed, failed_msg
    
    assert_not_includes Message.pending, queued_msg
    assert_not_includes Message.sent, pending_msg
  end
  
  # Legacy Message status methods removed - use MessageDelivery for individual tracking
  
  def test_create_in_conversation_creates_single_message
    conversation = create(:conversation, participant_identifiers: ['+12016661234', '+18045551234', '+15551234567'])
    
    message = Message.create_in_conversation!(conversation.id, {
      sender: '+12016661234',
      message_type: 'sms',
      body: 'Test message',
      timestamp: Time.current
    })
    
    # Should create single message object
    assert_instance_of Message, message
    
    # Message should have correct attributes
    assert_equal '+12016661234', message.sender.identifier
    assert_equal 'Test message', message.body
    assert_equal 'sms', message.message_type
    assert_equal 'sending', message.status # Message status when deliveries are created
  end
  
  def test_create_in_conversation_validates_sender_participation
    conversation = create(:conversation, participant_identifiers: ['+12016661234', '+18045551234'])
    
    assert_raises(ArgumentError, /not a participant/) do
      Message.create_in_conversation!(conversation.id, {
        sender: '+15551234567',  # Not in conversation
        message_type: 'sms',
        body: 'Test message',
        timestamp: Time.current
      })
    end
  end

  def test_aggregate_status_all_delivered
    message = create(:message)
    delivery1 = create(:message_delivery, message: message, status: 'delivered')
    delivery2 = create(:message_delivery, message: message, status: 'delivered')
    
    message.update_aggregate_status!
    
    assert_equal 'delivered', message.reload.status
  end
  
  def test_aggregate_status_all_sent
    message = create(:message)
    delivery1 = create(:message_delivery, message: message, status: 'sent')
    delivery2 = create(:message_delivery, message: message, status: 'sent')
    
    message.update_aggregate_status!
    
    assert_equal 'sent', message.reload.status
  end
  
  def test_aggregate_status_partial_success
    message = create(:message)
    delivery1 = create(:message_delivery, message: message, status: 'sent')
    delivery2 = create(:message_delivery, message: message, status: 'failed')
    
    message.update_aggregate_status!
    
    assert_equal 'partial', message.reload.status
  end
  
  def test_aggregate_status_all_failed
    message = create(:message)
    delivery1 = create(:message_delivery, message: message, status: 'failed')
    delivery2 = create(:message_delivery, message: message, status: 'failed')
    
    message.update_aggregate_status!
    
    assert_equal 'failed', message.reload.status
  end
  
  def test_aggregate_status_still_sending
    message = create(:message)
    delivery1 = create(:message_delivery, message: message, status: 'sent')
    delivery2 = create(:message_delivery, message: message, status: 'sending')
    
    message.update_aggregate_status!
    
    assert_equal 'sending', message.reload.status
  end
  
  def test_aggregate_status_progression_scenario
    # Test a realistic scenario where deliveries complete one by one
    message = create(:message)
    bob_delivery = create(:message_delivery, message: message, status: 'pending')
    charlie_delivery = create(:message_delivery, message: message, status: 'pending')
    dave_delivery = create(:message_delivery, message: message, status: 'pending')
    
    # Initially all pending - should be sending
    message.update_aggregate_status!
    assert_equal 'sending', message.reload.status
    
    # Bob's delivery succeeds
    bob_delivery.mark_as_sent!('provider_123')
    assert_equal 'sending', message.reload.status  # Still sending others
    
    # Charlie's delivery succeeds  
    charlie_delivery.mark_as_sent!('provider_456')
    assert_equal 'sending', message.reload.status  # Still sending Dave
    
    # Dave's delivery succeeds - now ALL are sent
    dave_delivery.mark_as_sent!('provider_789')
    assert_equal 'sent', message.reload.status  # Now all sent!
    
    # If one gets delivered confirmation
    bob_delivery.mark_as_delivered!
    assert_equal 'sent', message.reload.status  # Still 'sent' (not all delivered)
    
    # If all get delivered confirmations
    charlie_delivery.mark_as_delivered!
    dave_delivery.mark_as_delivered!
    assert_equal 'delivered', message.reload.status  # Now all delivered!
  end
  
  def test_aggregate_status_handles_failure_during_sending
    # Test what happens when some succeed and some fail
    message = create(:message)
    bob_delivery = create(:message_delivery, message: message, status: 'pending')
    charlie_delivery = create(:message_delivery, message: message, status: 'pending')
    dave_delivery = create(:message_delivery, message: message, status: 'pending')
    
    # Bob succeeds
    bob_delivery.mark_as_sent!('provider_123')
    assert_equal 'sending', message.reload.status
    
    # Charlie fails
    charlie_delivery.mark_as_failed!('Provider timeout')
    assert_equal 'partial', message.reload.status  # Now partial (success + failure)
    
    # Dave succeeds
    dave_delivery.mark_as_sent!('provider_789')
    assert_equal 'partial', message.reload.status  # Mixed results = partial
  end
end