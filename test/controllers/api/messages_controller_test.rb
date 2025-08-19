require "test_helper"

class Api::MessagesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @participant1 = '+12016661234'
    @participant2 = '+18045551234'
    @valid_sms_params = {
      from: @participant1,
      to: @participant2,
      type: 'sms',
      body: 'Hello! This is a test SMS message.',
      timestamp: '2024-11-01T14:00:00Z'
    }

    @valid_mms_params = {
      from: @participant1,
      to: @participant2,
      type: 'mms',
      body: 'Hello! This is a test MMS message.',
      attachments: ['https://example.com/image.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }

    @valid_email_params = {
      from: 'user@usehatchapp.com',
      to: 'contact@gmail.com',
      type: 'email',
      body: 'Hello! This is a test email with <b>HTML</b> formatting.',
      attachments: ['https://example.com/document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }
  end

  def test_send_sms_creates_new_sms_message
    assert_difference 'Message.count', 1 do  # One message per recipient (1 recipient in this case)
      post '/api/messages', params: @valid_sms_params, as: :json

      assert_response :created  # 201 for created messages
      json_response = JSON.parse(response.body)
      assert json_response['success']
      assert_includes json_response['data'], 'message_id'
      assert_includes json_response['data'], 'conversation_id'
      assert_includes json_response['data'], 'status'
      assert_includes json_response['data'], 'status_url'
      assert_equal 'sending', json_response['data']['status']
    end
  end

  def test_send_sms_creates_new_conversation_if_none_exists
    assert_difference 'Conversation.count', 1 do
      post '/api/messages', params: @valid_sms_params, as: :json
    end
  end

  def test_send_sms_sets_correct_message_attributes
    post '/api/messages', params: @valid_sms_params, as: :json
    
    message = Message.last
    assert_equal @valid_sms_params[:from], message.sender.identifier
    assert_equal 'sending', message.status
    assert_equal @valid_sms_params[:type], message.message_type
    assert_equal @valid_sms_params[:body], message.body
    # Provider ID is set after job processes, not immediately
    assert_nil message.provider_message_id
  end

  def test_send_sms_creates_mms_message_with_attachments
    post '/api/messages', params: @valid_mms_params, as: :json
    
    message = Message.last
    assert_equal 'mms', message.message_type
    assert_equal ['https://example.com/image.jpg'], message.attachments
  end

  def test_send_sms_handles_missing_required_fields
    post '/api/messages', params: { from: '+12016661234' }, as: :json
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_equal false, json_response['success']
    assert_equal 'type parameter is required when not using existing conversation_id', json_response['error']
  end

  def test_send_sms_handles_rate_limit_error
    # Unstub jobs for this test so we can test job execution
    SendMessageJob.unstub(:perform_later)
    
    MessageProviderService.stubs(:send_sms)
      .raises(MessageProviderService::RateLimitError, 'Too many requests')
    
    # Message is created and queued successfully
    assert_difference 'Message.count', 1 do
      post '/api/messages', params: @valid_sms_params, as: :json
      assert_response :created  # Controller returns 201 for successful creation
    end
    
    # Process the enqueued job to trigger the error
    perform_enqueued_jobs
    
    # Job processes and message should be marked as failed
    message = Message.last
    message.reload  # Refresh from database
    assert_equal 'failed', message.status
    
    # Check delivery-level failure tracking
    delivery = message.message_deliveries.first
    assert_not_nil delivery.failed_at
    assert_includes delivery.failure_reason, 'Too many requests'
    assert_equal 1, delivery.retry_count
  ensure
    # Re-stub jobs for other tests
    SendMessageJob.stubs(:perform_later).returns(true)
  end

  def test_send_sms_handles_server_error
    # Unstub jobs for this test so we can test job execution
    SendMessageJob.unstub(:perform_later)
    
    MessageProviderService.stubs(:send_sms)
      .raises(MessageProviderService::ServerError, 'Provider is down')
    
    # Message is created and queued successfully
    assert_difference 'Message.count', 1 do
      post '/api/messages', params: @valid_sms_params, as: :json
      assert_response :created  # Controller returns 201 for successful creation
    end
    
    # Process the enqueued job to trigger the error
    perform_enqueued_jobs
    
    # Job processes and message should be marked as failed
    message = Message.last
    message.reload  # Refresh from database
    assert_equal 'failed', message.status
    
    # Check delivery-level failure tracking
    delivery = message.message_deliveries.first
    assert_not_nil delivery.failed_at
    assert_includes delivery.failure_reason, 'Provider is down'
    assert_equal 1, delivery.retry_count
  ensure
    # Re-stub jobs for other tests
    SendMessageJob.stubs(:perform_later).returns(true)
  end

  def test_send_mms_handles_provider_error
    # Unstub jobs for this test so we can test job execution
    SendMessageJob.unstub(:perform_later)
    
    MessageProviderService.stubs(:send_mms)
      .raises(MessageProviderService::ProviderError.new('Custom error', 503))
    
    # Message is created and queued successfully
    assert_difference 'Message.count', 1 do
      post '/api/messages', params: @valid_mms_params, as: :json
      assert_response :created  # Controller returns 201 for successful creation
    end
    
    # Process the enqueued job to trigger the error
    perform_enqueued_jobs
    
    # Job processes and message should be marked as failed
    message = Message.last
    message.reload  # Refresh from database
    assert_equal 'failed', message.status
    
    # Check delivery-level failure tracking
    delivery = message.message_deliveries.first
    assert_not_nil delivery.failed_at
    assert_includes delivery.failure_reason, 'Custom error'
    assert_equal 1, delivery.retry_count
  ensure
    # Re-stub jobs for other tests
    SendMessageJob.stubs(:perform_later).returns(true)
  end

  def test_send_email_creates_new_email_message
    assert_difference 'Message.count', 1 do
      post '/api/messages', params: @valid_email_params, as: :json
    end
  end

  def test_send_email_returns_success_response
    post '/api/messages', params: @valid_email_params, as: :json
    
    assert_response :created  # 201 for created messages
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_includes json_response['data'], 'status'
    assert_equal 'sending', json_response['data']['status']
    assert_includes json_response['data'], 'message_id'
    assert_includes json_response['data'], 'status_url'
  end

  def test_send_email_sets_correct_email_attributes
    post '/api/messages', params: @valid_email_params, as: :json
    
    message = Message.last
    assert_equal 'email', message.message_type
    assert_equal 'sending', message.status  # Initially queued
    assert_not_nil message.queued_at
    # Provider ID is set after job processes, not immediately
    assert_nil message.provider_message_id
  end

  def test_send_email_handles_rate_limit_error
    # Unstub jobs for this test so we can test job execution
    SendMessageJob.unstub(:perform_later)
    
    MessageProviderService.stubs(:send_email)
      .raises(MessageProviderService::RateLimitError, 'Email rate limit exceeded')
    
    # Message is created and queued successfully
    assert_difference 'Message.count', 1 do
      post '/api/messages', params: @valid_email_params, as: :json
      assert_response :created  # Controller returns 201 for successful creation
    end
    
    # Process the enqueued job to trigger the error
    perform_enqueued_jobs
    
    # Job processes and message should be marked as failed
    message = Message.last
    message.reload  # Refresh from database
    assert_equal 'failed', message.status
    
    # Check delivery-level failure tracking
    delivery = message.message_deliveries.first
    assert_not_nil delivery.failed_at
    assert_includes delivery.failure_reason, 'Email rate limit exceeded'
    assert_equal 1, delivery.retry_count
  ensure
    # Re-stub jobs for other tests
    SendMessageJob.stubs(:perform_later).returns(true)
  end

  def test_send_sms_reuses_existing_conversation_between_same_participants
    # Create an existing conversation between the participants
    existing_conversation = create(:conversation, participant_identifiers: [@participant1, @participant2])
    
    # Verify we start with 1 conversation
    assert_equal 1, Conversation.count
    
    # Send an SMS message between the same participants
    post '/api/messages', params: @valid_sms_params, as: :json
    
    assert_response :created  # 201 for created messages
    
    # Verify no new conversation was created
    assert_equal 1, Conversation.count
    
    # Verify the message was added to the existing conversation
    message = Message.last
    assert_equal existing_conversation.id, message.conversation_id
    
    # Verify response includes the existing conversation ID
    json_response = JSON.parse(response.body)
    assert_equal existing_conversation.id, json_response['data']['conversation_id']
  end

  def test_send_sms_reuses_conversation_regardless_of_participant_order
    # Create conversation using the model method to ensure proper normalization
    existing_conversation = Conversation.find_or_create_for_participants(@participant2, @participant1, 'sms')
    
    # Verify we start with 1 conversation
    assert_equal 1, Conversation.count
    
    # Send message with participants in reverse order
    post '/api/messages', params: {
      from: @participant1,
      to: @participant2,
      type: 'sms',
      body: 'Testing participant order',
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for created messages
    
    # Should still reuse the existing conversation
    assert_equal 1, Conversation.count
    
    message = Message.last
    assert_equal existing_conversation.id, message.conversation_id
  end

  def test_send_sms_with_explicit_conversation_id
    # Create a conversation and participants
    conversation = create(:conversation, participant_identifiers: [@participant1, @participant2])
    
    post '/api/messages', params: {
      conversation_id: conversation.id,
      from: @participant1,
      type: 'sms',
      body: 'Message sent to specific conversation',
      timestamp: '2024-11-01T15:00:00Z'
    }, as: :json
    
    assert_response :created
    
    # Verify message was created in the specified conversation
    message = Message.last
    assert_equal conversation.id, message.conversation_id
    assert_equal @participant1, message.sender.identifier
    
    json_response = JSON.parse(response.body)
    assert_equal conversation.id, json_response['data']['conversation_id']
  end

  def test_send_sms_with_invalid_conversation_id
    post '/api/messages', params: {
      conversation_id: 99999,
      from: @participant1,
      type: 'sms',
      body: 'Message to invalid conversation',
      timestamp: '2024-11-01T15:00:00Z'
    }, as: :json
    
    assert_response :not_found
  end

  def test_send_sms_with_unauthorized_sender
    # Create conversation without the sender as participant
    other_participant = '+15551234567'
    conversation = create(:conversation, participant_identifiers: [@participant1, @participant2])
    
    post '/api/messages', params: {
      conversation_id: conversation.id,
      from: other_participant,
      type: 'sms',
      body: 'Unauthorized message',
      timestamp: '2024-11-01T15:00:00Z'
    }, as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_match(/not a participant/, json_response['error'])
  end

  def test_unified_create_endpoint_sms
    conversation = create(:conversation, participant_identifiers: [@participant1, @participant2])
    
    post '/api/messages', params: {
      conversation_id: conversation.id,
      from: @participant1,
      type: 'sms',
      body: 'Unified endpoint SMS',
      timestamp: '2024-11-01T15:00:00Z'
    }, as: :json
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 'sending', json_response['data']['status']
    assert_includes json_response['data'], 'message_id'
    assert_includes json_response['data'], 'status_url'
    
    message = Message.last
    assert_equal 'sms', message.message_type
    assert_equal 'Unified endpoint SMS', message.body
  end

  def test_unified_create_endpoint_email
    conversation = create(:conversation, message_type: 'email', participant_identifiers: ['user@example.com', 'contact@example.com'])
    
    post '/api/messages', params: {
      conversation_id: conversation.id,
      from: 'user@example.com',
      body: 'Unified endpoint email',  # No type needed - taken from conversation
      timestamp: '2024-11-01T15:00:00Z'
    }, as: :json
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 'sending', json_response['data']['status']
    assert_includes json_response['data'], 'message_id'
    assert_includes json_response['data'], 'status_url'
    
    message = Message.last
    assert_equal 'email', message.message_type
    assert_equal 'Unified endpoint email', message.body
  end

  def test_unified_create_requires_conversation_id
    post '/api/messages', params: {
      from: @participant1,
      type: 'sms',
      body: 'No conversation ID'
    }, as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_match(/Both from and to parameters are required when not using existing conversation_id/, json_response['error'])
  end

  def test_unified_create_with_conversation_id_no_type_needed
    conversation = create(:conversation, participant_identifiers: [@participant1, @participant2])
    
    # Should succeed - type is taken from conversation
    post '/api/messages', params: {
      conversation_id: conversation.id,
      from: @participant1,
      body: 'No type specified - taken from conversation'
    }, as: :json
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response['success']
    
    message = Message.find(json_response['data']['message_id'])
    assert_equal 'sms', message.message_type  # Default from conversation factory
  end

  def test_create_group_message_with_multiple_recipients
    # Test creating a group message with multiple recipients
    assert_difference 'Message.count', 1 do
      assert_difference 'Conversation.count', 1 do
        post '/api/messages', params: {
          from: '+12016661234',
          to: ['+18045551234', '+15551239999', '+15551234567'],  # Array of recipients
          type: 'sms',
          body: 'Hello group!',
          timestamp: '2024-11-01T14:00:00Z'
        }, as: :json
      end
    end
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_includes json_response['data'], 'message_id'
    assert_includes json_response['data'], 'conversation_id'
    assert_equal 'sending', json_response['data']['status']
    
    # Verify conversation has all 4 participants (sender + 3 recipients)
    conversation = Conversation.find(json_response['data']['conversation_id'])
    assert_equal 4, conversation.participants.count
    assert_equal 'sms', conversation.message_type
    
    participant_identifiers = conversation.participants.pluck(:identifier).sort
    expected_identifiers = ['+12016661234', '+15551234567', '+15551239999', '+18045551234']
    assert_equal expected_identifiers, participant_identifiers
  end

  def test_reuse_existing_conversation_without_type_param
    # First, create a conversation
    post '/api/messages', params: {
      from: '+12016661234',
      to: ['+18045551234', '+15551239999'],
      type: 'email',
      body: 'First message',
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    first_response = JSON.parse(response.body)
    conversation_id = first_response['data']['conversation_id']
    
    # Now send another message using the conversation_id (no type needed)
    assert_difference 'Message.count', 1 do
      assert_no_difference 'Conversation.count' do  # Should reuse existing conversation
        post '/api/messages', params: {
          conversation_id: conversation_id,
          from: '+18045551234',  # Different sender in same conversation
          body: 'Reply message - no type param needed!',
          timestamp: '2024-11-01T14:30:00Z'
        }, as: :json
      end
    end
    
    assert_response :created
    second_response = JSON.parse(response.body)
    assert second_response['success']
    assert_equal conversation_id, second_response['data']['conversation_id']
    
    # Verify the message has the correct type from conversation
    message = Message.find(second_response['data']['message_id'])
    assert_equal 'email', message.message_type
  end

  def test_different_message_types_create_separate_conversations
    # Create SMS conversation
    post '/api/messages', params: {
      from: '+12016661234',
      to: ['+18045551234'],
      type: 'sms',
      body: 'SMS message'
    }, as: :json
    
    assert_response :created
    sms_response = JSON.parse(response.body)
    sms_conversation_id = sms_response['data']['conversation_id']
    
    # Create email conversation with same participants
    post '/api/messages', params: {
      from: '+12016661234',
      to: ['+18045551234'],
      type: 'email',
      body: 'Email message'
    }, as: :json
    
    assert_response :created
    email_response = JSON.parse(response.body)
    email_conversation_id = email_response['data']['conversation_id']
    
    # Should be different conversations because different message types
    assert_not_equal sms_conversation_id, email_conversation_id
    
    sms_conversation = Conversation.find(sms_conversation_id)
    email_conversation = Conversation.find(email_conversation_id)
    
    assert_equal 'sms', sms_conversation.message_type
    assert_equal 'email', email_conversation.message_type
  end
end