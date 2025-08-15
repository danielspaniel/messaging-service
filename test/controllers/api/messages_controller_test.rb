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

      assert_response :created
      json_response = JSON.parse(response.body)
      assert json_response['success']
      assert_includes json_response['data'], 'message_id'
      assert_includes json_response['data'], 'provider_id'
      assert_includes json_response['data'], 'conversation_id'
      assert_includes json_response['data'], 'status'
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
    assert_equal 'sms_provider', message.messaging_provider_id
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
    
    post '/api/messages/sms', params: @valid_sms_params, as: :json
    
    assert_response 429
    json_response = JSON.parse(response.body)
    assert_equal 'Rate limit exceeded', json_response['error']
    assert_equal 'Too many requests', json_response['message']
    assert_equal 60, json_response['retry_after']
  end

  def test_send_sms_handles_server_error
    MessageProviderService.stubs(:send_sms)
      .raises(MessageProviderService::ServerError, 'Provider is down')
    
    post '/api/messages/sms', params: @valid_sms_params, as: :json
    
    assert_response 502
    json_response = JSON.parse(response.body)
    assert_equal 'Provider server error', json_response['error']
    assert_equal 'Provider is down', json_response['message']
  end

  def test_send_mms_handles_provider_error
    MessageProviderService.stubs(:send_mms)
      .raises(MessageProviderService::ProviderError.new('Custom error', 503))
    
    post '/api/messages/sms', params: @valid_mms_params, as: :json
    
    assert_response 503
    json_response = JSON.parse(response.body)
    assert_equal 'Provider error', json_response['error']
    assert_equal 'Custom error', json_response['message']
  end

  def test_send_email_creates_new_email_message
    assert_difference 'Message.count', 1 do
      post '/api/messages/email', params: @valid_email_params, as: :json
    end
  end

  def test_send_email_returns_success_response
    post '/api/messages/email', params: @valid_email_params, as: :json
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response['success']
  end

  def test_send_email_sets_correct_email_attributes
    post '/api/messages/email', params: @valid_email_params, as: :json
    
    message = Message.last
    assert_equal 'email', message.message_type
    assert_not_nil message.xillio_id
    assert_nil message.messaging_provider_id
  end

  def test_send_email_handles_rate_limit_error
    MessageProviderService.stubs(:send_email)
      .raises(MessageProviderService::RateLimitError, 'Email rate limit exceeded')
    
    post '/api/messages/email', params: @valid_email_params, as: :json
    
    assert_response 429
    json_response = JSON.parse(response.body)
    assert_equal 'Rate limit exceeded', json_response['error']
    assert_equal 'Email rate limit exceeded', json_response['message']
  end

  def test_send_sms_reuses_existing_conversation_between_same_participants
    # Create an existing conversation between the participants
    existing_conversation = create(:conversation, participants: [@participant1, @participant2])
    
    # Verify we start with 1 conversation
    assert_equal 1, Conversation.count
    
    # Send an SMS message between the same participants
    post '/api/messages/sms', params: @valid_sms_params, as: :json
    
    assert_response :created
    
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
    
    assert_response :created
    
    # Should still reuse the existing conversation
    assert_equal 1, Conversation.count
    
    message = Message.last
    assert_equal existing_conversation.id, message.conversation_id
  end
end