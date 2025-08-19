require 'test_helper'

class SendMessageJobTest < ActiveJob::TestCase
  def setup
    @conversation = create(:conversation, participant_identifiers: ['+12016661234', '+18045551234'])
    @sender = @conversation.participants.first
    @message = create(:message, 
      conversation: @conversation, 
      sender: @sender,
      status: 'queued',
      message_type: 'sms',
      body: 'Test message'
    )
  end

  def test_perform_sms_message_successfully_with_delivery
    recipient = @conversation.participants.where.not(id: @sender.id).first
    delivery = create(:message_delivery, message: @message, recipient: recipient, status: 'pending')
    
    # Mock the provider service for specific recipient
    provider_response = { provider_id: 'test_provider_123' }
    MessageProviderService.expects(:send_sms).with({
      from: @sender.identifier,
      to: recipient.identifier,
      type: 'sms',
      body: 'Test message',
      attachments: [],
      timestamp: @message.timestamp
    }).returns(provider_response).once
    
    # Run the job with specific delivery
    SendMessageJob.new.perform(@message.id, delivery.id)
    
    # Check delivery was marked as sent
    delivery.reload
    assert_equal 'sent', delivery.status
    assert_equal 'test_provider_123', delivery.provider_message_id
    assert_not_nil delivery.sent_at
  end

  # Backward compatibility test removed - delivery_id is now required

  def test_perform_email_message_successfully
    @message.update!(message_type: 'email')
    recipient = @conversation.participants.where.not(id: @sender.id).first
    delivery = create(:message_delivery, message: @message, recipient: recipient, status: 'pending')
    
    # Mock the provider service
    provider_response = { provider_id: 'email_provider_456' }
    MessageProviderService.expects(:send_email).returns(provider_response)
    
    # Run the job with specific delivery
    SendMessageJob.new.perform(@message.id, delivery.id)
    
    # Check delivery was marked as sent
    delivery.reload
    assert_equal 'sent', delivery.status
    assert_equal 'email_provider_456', delivery.provider_message_id
    assert_not_nil delivery.sent_at
  end

  def test_perform_handles_provider_error
    recipient = @conversation.participants.where.not(id: @sender.id).first
    delivery = create(:message_delivery, message: @message, recipient: recipient, status: 'sending')
    
    # Mock provider service to raise error
    MessageProviderService.expects(:send_sms).raises(MessageProviderService::ProviderError.new('Provider timeout'))
    
    # Run the job with specific delivery
    SendMessageJob.new.perform(@message.id, delivery.id)
    
    # Check delivery was marked as failed
    delivery.reload
    assert_equal 'failed', delivery.status
    assert_equal 'Provider timeout', delivery.failure_reason
  end

  def test_perform_handles_unexpected_error
    recipient = @conversation.participants.where.not(id: @sender.id).first
    delivery = create(:message_delivery, message: @message, recipient: recipient, status: 'sending')
    
    # Mock provider service to raise unexpected error
    MessageProviderService.expects(:send_sms).raises(StandardError.new('Unexpected error'))
    
    # Run the job with specific delivery
    SendMessageJob.new.perform(@message.id, delivery.id)
    
    # Check delivery was marked as failed
    delivery.reload
    assert_equal 'failed', delivery.status
    assert_equal 'Unexpected error', delivery.failure_reason
  end

  # Legacy test removed - delivery_id is now required

  def test_perform_with_unknown_message_type
    recipient = @conversation.participants.where.not(id: @sender.id).first
    delivery = create(:message_delivery, message: @message, recipient: recipient, status: 'sending')
    
    # Bypass validation to test job error handling
    @message.update_column(:message_type, 'unknown')
    
    # Run the job with specific delivery
    SendMessageJob.new.perform(@message.id, delivery.id)
    
    # Check delivery was marked as failed
    delivery.reload
    assert_equal 'failed', delivery.status
    assert_match(/Unknown message type/, delivery.failure_reason)
  end

  def test_group_message_creates_deliveries_and_queues_jobs
    # Unstub jobs for this test
    SendMessageJob.unstub(:perform_later)
    
    # Create a group conversation with 3 participants + sender
    group_conversation = create(:conversation, 
      participant_identifiers: ['+12016661234', '+18045551234', '+15551239999', '+15551234567'],
      message_type: 'sms'
    )
    
    # Track job enqueues and delivery creation
    assert_enqueued_jobs 3, only: SendMessageJob do
      assert_difference 'MessageDelivery.count', 3 do
        message = Message.create_in_conversation!(group_conversation.id, {
          sender: '+12016661234',
          message_type: 'sms',
          body: 'Hello group!',
          timestamp: Time.current
        })
        
        # Verify message starts in 'sending' status
        assert_equal 'sending', message.status
        
        # Verify 3 delivery records created
        assert_equal 3, message.message_deliveries.count
        message.message_deliveries.each do |delivery|
          assert_equal 'pending', delivery.status
          assert_not_equal message.sender.id, delivery.recipient.id
        end
      end
    end
  ensure
    # Re-stub jobs for other tests
    SendMessageJob.stubs(:perform_later).returns(true)
  end
end
