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
      body: 'Hello! This is a test email with <b>HTML</b> formatting.',
      attachments: ['https://example.com/document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }
  end

  def test_send_sms_creates_new_sms_message
    assert_difference 'Message.count', 1 do
      post '/api/messages/sms', params: @valid_sms_params, as: :json

      assert_response :accepted  # 202 for queued messages
      json_response = JSON.parse(response.body)
      assert json_response['success']
      assert_includes json_response['data'], 'message_id'
      assert_includes json_response['data'], 'conversation_id'
      assert_includes json_response['data'], 'status'
      assert_includes json_response['data'], 'status_url'
      assert_equal 'queued', json_response['data']['status']
    end
  end

  def test_send_sms_creates_new_conversation_if_none_exists
    assert_difference 'Conversation.count', 1 do
      post '/api/messages/sms', params: @valid_sms_params, as: :json
    end
  end

  def test_send_sms_sets_correct_message_attributes
    post '/api/messages/sms', params: @valid_sms_params, as: :json
    
    message = Message.last
    assert_equal @valid_sms_params[:from], message.from
    assert_equal @valid_sms_params[:to], message.to
    assert_equal @valid_sms_params[:type], message.message_type
    assert_equal @valid_sms_params[:body], message.body
    assert_equal 'outbound', message.direction
    assert_equal 'queued', message.status  # Initially queued
    assert_not_nil message.queued_at
    # Provider ID is set after job processes, not immediately
    assert_nil message.messaging_provider_id
  end

  def test_send_sms_creates_mms_message_with_attachments
    post '/api/messages/sms', params: @valid_mms_params, as: :json
    
    message = Message.last
    assert_equal 'mms', message.message_type
    assert_equal ['https://example.com/image.jpg'], message.attachments
  end

  def test_send_sms_handles_missing_required_fields
    post '/api/messages/sms', params: { from: '+12016661234' }, as: :json
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_equal false, json_response['success']
    assert_equal 'Missing message type', json_response['error']
  end

  def test_send_sms_handles_rate_limit_error
    MessageProviderService.stubs(:send_sms)
      .raises(MessageProviderService::RateLimitError, 'Too many requests')
    
    # Message is created and queued successfully
    assert_difference 'Message.count', 1 do
      post '/api/messages/sms', params: @valid_sms_params, as: :json
      assert_response :accepted  # Controller always returns 202
    end
    
    # Process the enqueued job to trigger the error
    perform_enqueued_jobs
    
    # Job processes and message should be marked as failed
    message = Message.last
    message.reload  # Refresh from database
    assert_equal 'failed', message.status
    assert_not_nil message.failed_at
    assert_includes message.error_message, 'Too many requests'
    assert_equal 1, message.retry_count
  end

  def test_send_sms_handles_server_error
    MessageProviderService.stubs(:send_sms)
      .raises(MessageProviderService::ServerError, 'Provider is down')
    
    # Message is created and queued successfully
    assert_difference 'Message.count', 1 do
      post '/api/messages/sms', params: @valid_sms_params, as: :json
      assert_response :accepted  # Controller always returns 202
    end
    
    # Process the enqueued job to trigger the error
    perform_enqueued_jobs
    
    # Job processes and message should be marked as failed
    message = Message.last
    message.reload  # Refresh from database
    assert_equal 'failed', message.status
    assert_not_nil message.failed_at
    assert_includes message.error_message, 'Provider is down'
    assert_equal 1, message.retry_count
  end

  def test_send_mms_handles_provider_error
    MessageProviderService.stubs(:send_mms)
      .raises(MessageProviderService::ProviderError.new('Custom error', 503))
    
    # Message is created and queued successfully
    assert_difference 'Message.count', 1 do
      post '/api/messages/sms', params: @valid_mms_params, as: :json
      assert_response :accepted  # Controller always returns 202
    end
    
    # Process the enqueued job to trigger the error
    perform_enqueued_jobs
    
    # Job processes and message should be marked as failed
    message = Message.last
    message.reload  # Refresh from database
    assert_equal 'failed', message.status
    assert_not_nil message.failed_at
    assert_includes message.error_message, 'Custom error'
    assert_equal 1, message.retry_count
  end

  def test_send_email_creates_new_email_message
    assert_difference 'Message.count', 1 do
      post '/api/messages/email', params: @valid_email_params, as: :json
    end
  end

  def test_send_email_returns_success_response
    post '/api/messages/email', params: @valid_email_params, as: :json
    
    assert_response :accepted  # 202 for queued messages
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_includes json_response['data'], 'status'
    assert_equal 'queued', json_response['data']['status']
  end

  def test_send_email_sets_correct_email_attributes
    post '/api/messages/email', params: @valid_email_params, as: :json
    
    message = Message.last
    assert_equal 'email', message.message_type
    assert_equal 'queued', message.status  # Initially queued
    assert_not_nil message.queued_at
    # Provider IDs are set after job processes, not immediately
    assert_nil message.xillio_id
    assert_nil message.messaging_provider_id
  end

  def test_send_email_handles_rate_limit_error
    MessageProviderService.stubs(:send_email)
      .raises(MessageProviderService::RateLimitError, 'Email rate limit exceeded')
    
    # Message is created and queued successfully
    assert_difference 'Message.count', 1 do
      post '/api/messages/email', params: @valid_email_params, as: :json
      assert_response :accepted  # Controller always returns 202
    end
    
    # Process the enqueued job to trigger the error
    perform_enqueued_jobs
    
    # Job processes and message should be marked as failed
    message = Message.last
    message.reload  # Refresh from database
    assert_equal 'failed', message.status
    assert_not_nil message.failed_at
    assert_includes message.error_message, 'Email rate limit exceeded'
    assert_equal 1, message.retry_count
  end

  def test_send_sms_reuses_existing_conversation_between_same_participants
    # Create an existing conversation between the participants
    existing_conversation = create(:conversation, participants: [@participant1, @participant2])
    
    # Verify we start with 1 conversation
    assert_equal 1, Conversation.count
    
    # Send an SMS message between the same participants
    post '/api/messages/sms', params: @valid_sms_params, as: :json
    
    assert_response :accepted  # 202 for queued messages
    
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
    existing_conversation = Conversation.find_or_create_for_participants(@participant2, @participant1)
    
    # Verify we start with 1 conversation
    assert_equal 1, Conversation.count
    
    # Send message with participants in reverse order
    post '/api/messages/sms', params: {
      from: @participant1,
      to: @participant2,
      type: 'sms',
      body: 'Testing participant order',
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :accepted  # 202 for queued messages
    
    # Should still reuse the existing conversation
    assert_equal 1, Conversation.count
    
    message = Message.last
    assert_equal existing_conversation.id, message.conversation_id
  end
end