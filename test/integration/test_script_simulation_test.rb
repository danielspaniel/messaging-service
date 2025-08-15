require "test_helper"

class TestScriptSimulationTest < ActionDispatch::IntegrationTest
  # This test simulates the exact behavior expected by bin/test.sh
  
  def setup
    # Mock provider responses to avoid random failures
    Api::MessagesController.any_instance.stubs(:simulate_provider_response)
  end

  def test_1_sms_send_endpoint
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'sms',
      body: 'Hello! This is a test SMS message.',
      attachments: nil,
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_includes response_data['data'], 'message_id'
    assert_includes response_data['data'], 'conversation_id'
  end

  def test_2_mms_send_endpoint
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'mms',
      body: 'Hello! This is a test MMS message with attachment.',
      attachments: ['https://example.com/image.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Verify MMS was created with attachment
    message = Message.last
    assert_equal 'mms', message.message_type
    assert_equal ['https://example.com/image.jpg'], message.attachments
  end

  def test_3_email_send_endpoint
    post '/api/messages/email', params: {
      from: 'user@usehatchapp.com',
      to: 'contact@gmail.com',
      body: 'Hello! This is a test email message with <b>HTML</b> formatting.',
      attachments: ['https://example.com/document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Verify email was created
    message = Message.last
    assert_equal 'email', message.message_type
    assert_not_nil message.xillio_id
  end

  def test_4_incoming_sms_webhook
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'sms',
      messaging_provider_id: 'message-1',
      body: 'This is an incoming SMS message',
      attachments: nil,
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Verify inbound SMS was created
    message = Message.last
    assert_equal 'sms', message.message_type
    assert_equal 'inbound', message.direction
    assert_equal 'message-1', message.messaging_provider_id
  end

  def test_5_incoming_mms_webhook
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'mms',
      messaging_provider_id: 'message-2',
      body: 'This is an incoming MMS message',
      attachments: ['https://example.com/received-image.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Verify inbound MMS was created
    message = Message.last
    assert_equal 'mms', message.message_type
    assert_equal 'inbound', message.direction
    assert_equal ['https://example.com/received-image.jpg'], message.attachments
  end

  def test_6_incoming_email_webhook
    post '/api/webhooks/email', params: {
      from: 'contact@gmail.com',
      to: 'user@usehatchapp.com',
      xillio_id: 'message-3',
      body: '<html><body>This is an incoming email with <b>HTML</b> content</body></html>',
      attachments: ['https://example.com/received-document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    response_data = JSON.parse(response.body)
    assert response_data['success']
    
    # Verify inbound email was created
    message = Message.last
    assert_equal 'email', message.message_type
    assert_equal 'inbound', message.direction
    assert_equal 'message-3', message.xillio_id
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
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'sms',
      body: 'Hello! This is a test SMS message.',
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    sms_conversation_id = JSON.parse(response.body)['data']['conversation_id']
    
    # Test 2: Send MMS
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'mms',
      body: 'Hello! This is a test MMS message with attachment.',
      attachments: ['https://example.com/image.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    # Should be same conversation as SMS
    assert_equal sms_conversation_id, JSON.parse(response.body)['data']['conversation_id']
    
    # Test 3: Send Email
    post '/api/messages/email', params: {
      from: 'user@usehatchapp.com',
      to: 'contact@gmail.com',
      body: 'Hello! This is a test email message with <b>HTML</b> formatting.',
      attachments: ['https://example.com/document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    email_conversation_id = JSON.parse(response.body)['data']['conversation_id']
    
    # Email should be in different conversation
    assert_not_equal sms_conversation_id, email_conversation_id
    
    # Test 4: Receive SMS webhook
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'sms',
      messaging_provider_id: 'message-1',
      body: 'This is an incoming SMS message',
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    # Should be same conversation as outbound SMS/MMS
    assert_equal sms_conversation_id, JSON.parse(response.body)['data']['conversation_id']
    
    # Test 5: Receive MMS webhook
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'mms',
      messaging_provider_id: 'message-2',
      body: 'This is an incoming MMS message',
      attachments: ['https://example.com/received-image.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    
    # Test 6: Receive Email webhook
    post '/api/webhooks/email', params: {
      from: 'contact@gmail.com',
      to: 'user@usehatchapp.com',
      xillio_id: 'message-3',
      body: '<html><body>This is an incoming email with <b>HTML</b> content</body></html>',
      attachments: ['https://example.com/received-document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :created
    # Should be same conversation as outbound email
    assert_equal email_conversation_id, JSON.parse(response.body)['data']['conversation_id']
    
    # Test 7: Get conversations
    get '/api/conversations', as: :json
    
    assert_response :success
    conversations = JSON.parse(response.body)['data']
    assert_equal 2, conversations.length # SMS/MMS conversation and Email conversation
    
    # Test 8: Get messages for SMS conversation
    get "/api/conversations/#{sms_conversation_id}/messages", as: :json
    
    assert_response :success
    sms_messages = JSON.parse(response.body)['data']
    assert_equal 4, sms_messages.length # 2 outbound (SMS, MMS) + 2 inbound (SMS, MMS)
    
    # Verify message types and directions
    message_types = sms_messages.map { |m| [m['message_type'], m['direction']] }
    expected_types = [
      ['sms', 'outbound'],
      ['mms', 'outbound'], 
      ['sms', 'inbound'],
      ['mms', 'inbound']
    ]
    
    expected_types.each do |expected_type|
      assert_includes message_types, expected_type
    end
  end
end