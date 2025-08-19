require "test_helper"

class TestScriptSimulationTest < ActionDispatch::IntegrationTest
  # This test simulates the exact behavior expected by bin/test.sh
  
  def setup
    # Mock provider responses to avoid random failures
    Api::MessagesController.any_instance.stubs(:simulate_provider_response)
  end

  def test_1_sms_send_endpoint
    post '/api/messages', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'sms',
      body: 'Hello! This is a test SMS message.',
      attachments: nil,
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for created messages
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_includes response_data['data'], 'message_id'
    assert_includes response_data['data'], 'conversation_id'
  end

  def test_2_mms_send_endpoint
    post '/api/messages', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'mms',
      body: 'Hello! This is a test MMS message with attachment.',
      attachments: ['https://example.com/image.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for created messages
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Verify MMS was created with attachment
    message = Message.last
    assert_equal 'mms', message.message_type
    assert_equal ['https://example.com/image.jpg'], message.attachments
  end

  def test_3_email_send_endpoint
    post '/api/messages', params: {
      from: 'user@usehatchapp.com',
      to: 'contact@gmail.com',
      type: 'email',
      body: 'Hello! This is a test email message with <b>HTML</b> formatting.',
      attachments: ['https://example.com/document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for created messages
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Verify email was created
    message = Message.last
    assert_equal 'email', message.message_type
    assert_equal 'sending', message.status  # Initially sending with deliveries
    # Provider ID is set after job processes
    assert_nil message.provider_message_id
  end

  def test_4_incoming_sms_webhook
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'sms',
      provider_message_id: 'message-1',
      body: 'This is an incoming SMS message',
      attachments: nil,
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for webhook messages (immediate)
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Verify inbound SMS was created
    message = Message.last
    assert_equal 'sms', message.message_type
    # Direction is no longer tracked - messages are inbound based on webhook source
    assert_equal 'message-1', message.provider_message_id
  end

  def test_5_incoming_mms_webhook
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'mms',
      provider_message_id: 'message-2',
      body: 'This is an incoming MMS message',
      attachments: ['https://example.com/received-image.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for webhook messages (immediate)
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Verify inbound MMS was created
    message = Message.last
    assert_equal 'mms', message.message_type
    # Direction is no longer tracked - messages are inbound based on webhook source
    assert_equal ['https://example.com/received-image.jpg'], message.attachments
  end

  def test_6_incoming_email_webhook
    post '/api/webhooks/email', params: {
      from: 'contact@gmail.com',
      to: 'user@usehatchapp.com',
      provider_message_id: 'message-3',
      body: '<html><body>This is an incoming email with <b>HTML</b> content</body></html>',
      attachments: ['https://example.com/received-document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for webhook messages (immediate)
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Verify inbound email was created
    message = Message.last
    assert_equal 'email', message.message_type
    # Direction is no longer tracked - messages are inbound based on webhook source
    assert_equal 'message-3', message.provider_message_id
  end

  def test_7_get_conversations_endpoint
    # Create some test data first
    conversation = create(:conversation, :with_messages)
    
    get '/api/conversations', as: :json
    
    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data'].is_a?(Array)
    assert response_data['data'].length > 0
  end

  def test_8_get_messages_for_conversation_endpoint
    # Create a conversation with messages
    conversation = create(:conversation, :with_messages)
    
    get "/api/conversations/#{conversation.id}/messages", as: :json
    
    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data'].is_a?(Array)
    assert_equal 3, response_data['data'].length # :with_messages creates 3 messages
  end

  def test_complete_test_script_workflow
    # Test 1: Send SMS
    post '/api/messages', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'sms',
      body: 'Hello! This is a test SMS message.',
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for created messages
    sms_conversation_id = JSON.parse(response.body)['data']['conversation_id']
    
    # Test 2: Send MMS
    post '/api/messages', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'mms',
      body: 'Hello! This is a test MMS message with attachment.',
      attachments: ['https://example.com/image.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for created messages
    # Should be different conversation from SMS (different message types)
    mms_conversation_id = JSON.parse(response.body)['data']['conversation_id']
    assert_not_equal sms_conversation_id, mms_conversation_id
    
    # Test 3: Send Email
    post '/api/messages', params: {
      from: 'user@usehatchapp.com',
      to: 'contact@gmail.com',
      type: 'email',
      body: 'Hello! This is a test email message with <b>HTML</b> formatting.',
      attachments: ['https://example.com/document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for created messages
    email_conversation_id = JSON.parse(response.body)['data']['conversation_id']
    
    # Email should be in different conversation
    assert_not_equal sms_conversation_id, email_conversation_id
    
    # Test 4: Receive SMS webhook
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'sms',
      provider_message_id: 'message-1',
      body: 'This is an incoming SMS message',
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for webhook messages (immediate)
    # Should be same conversation as outbound SMS/MMS
    assert_equal sms_conversation_id, JSON.parse(response.body)['data']['conversation_id']
    
    # Test 5: Receive MMS webhook
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'mms',
      provider_message_id: 'message-2',
      body: 'This is an incoming MMS message',
      attachments: ['https://example.com/received-image.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for webhook messages (immediate)
    
    # Test 6: Receive Email webhook
    post '/api/webhooks/email', params: {
      from: 'contact@gmail.com',
      to: 'user@usehatchapp.com',
      provider_message_id: 'message-3',
      body: '<html><body>This is an incoming email with <b>HTML</b> content</body></html>',
      attachments: ['https://example.com/received-document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created  # 201 for webhook messages (immediate)
    # Should be same conversation as outbound email
    assert_equal email_conversation_id, JSON.parse(response.body)['data']['conversation_id']
    
    # Test 7: Get conversations
    get '/api/conversations', as: :json
    
    assert_response :success
    conversations = JSON.parse(response.body)['data']
    assert_equal 3, conversations.length # SMS conversation, MMS conversation, and Email conversation
    
    # Test 8: Get messages for SMS conversation
    get "/api/conversations/#{sms_conversation_id}/messages", as: :json
    
    assert_response :success
    sms_messages = JSON.parse(response.body)['data']
    assert_equal 2, sms_messages.length # 1 outbound SMS + 1 inbound SMS
    
    # Verify message types (only SMS messages in SMS conversation)
    message_types = sms_messages.map { |m| m['message_type'] }
    assert_equal ['sms', 'sms'], message_types.sort
  end
end