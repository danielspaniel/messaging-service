require "test_helper"

class MessagingFlowTest < ActionDispatch::IntegrationTest
  def test_complete_sms_messaging_workflow
    # Send outbound SMS
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'sms',
      body: 'Hello! How are you?',
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :accepted  # 202 for queued messages
    outbound_response = JSON.parse(response.body)
    conversation_id = outbound_response['data']['conversation_id']
    
    # Simulate incoming SMS response
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'sms',
      messaging_provider_id: 'incoming-msg-1',
      body: 'Hi there! I am doing well, thanks for asking.',
      timestamp: '2024-11-01T14:05:00Z'
    }, as: :json
    
    assert_response :created  # 201 for webhook messages (immediate)
    inbound_response = JSON.parse(response.body)
    
    # Verify both messages are in the same conversation
    assert_equal conversation_id, inbound_response['data']['conversation_id']
    
    # Check conversation has both messages
    get "/api/conversations/#{conversation_id}/messages", as: :json
    
    assert_response :success
    messages_response = JSON.parse(response.body)
    messages = messages_response['data']
    
    assert_equal 2, messages.length
    assert_equal 'outbound', messages.first['direction']
    assert_equal 'inbound', messages.last['direction']
  end

  def test_mms_with_attachments_workflow
    # Send outbound MMS with attachment
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'mms',
      body: 'Check out this image!',
      attachments: ['https://example.com/photo.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :accepted  # 202 for queued messages
    outbound_response = JSON.parse(response.body)
    conversation_id = outbound_response['data']['conversation_id']
    
    # Simulate incoming MMS response
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'mms',
      messaging_provider_id: 'incoming-mms-1',
      body: 'Nice photo! Here is mine.',
      attachments: ['https://example.com/reply-photo.jpg'],
      timestamp: '2024-11-01T14:05:00Z'
    }, as: :json
    
    assert_response :created  # 201 for webhook messages (immediate)
    
    # Verify messages have attachments
    get "/api/conversations/#{conversation_id}/messages", as: :json
    
    messages = JSON.parse(response.body)['data']
    assert_equal ['https://example.com/photo.jpg'], messages.first['attachments']
    assert_equal ['https://example.com/reply-photo.jpg'], messages.last['attachments']
  end

  def test_email_messaging_workflow
    # Send outbound email
    post '/api/messages/email', params: {
      from: 'user@usehatchapp.com',
      to: 'contact@gmail.com',
      body: 'Hello! This is an important <b>HTML</b> email.',
      attachments: ['https://example.com/document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }, as: :json
    
    assert_response :accepted  # 202 for queued messages
    outbound_response = JSON.parse(response.body)
    conversation_id = outbound_response['data']['conversation_id']
    
    # Simulate incoming email response
    post '/api/webhooks/email', params: {
      from: 'contact@gmail.com',
      to: 'user@usehatchapp.com',
      xillio_id: 'email-reply-1',
      body: '<html><body>Thank you for your email! I received the document.</body></html>',
      attachments: [],
      timestamp: '2024-11-01T14:30:00Z'
    }, as: :json
    
    assert_response :created  # 201 for webhook messages (immediate)
    
    # Verify conversation contains both email messages
    get "/api/conversations/#{conversation_id}/messages", as: :json
    
    messages = JSON.parse(response.body)['data']
    assert_equal 2, messages.length
    assert messages.all? { |m| m['message_type'] == 'email' }
  end

  def test_separate_conversations_for_different_participants
    # Conversation 1: User A and User B
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'sms',
      body: 'Hello User B!'
    }, as: :json
    
    conversation1_id = JSON.parse(response.body)['data']['conversation_id']
    
    # Conversation 2: User A and User C
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+15551234567',
      type: 'sms',
      body: 'Hello User C!'
    }, as: :json
    
    conversation2_id = JSON.parse(response.body)['data']['conversation_id']
    
    # Verify different conversations were created
    assert_not_equal conversation1_id, conversation2_id
    
    # Verify conversations list includes both
    get '/api/conversations', as: :json
    
    conversations = JSON.parse(response.body)['data']
    conversation_ids = conversations.map { |c| c['id'] }
    
    assert_includes conversation_ids, conversation1_id
    assert_includes conversation_ids, conversation2_id
  end

  def test_provider_failure_handling
    # Simulate provider failure
    MessageProviderService.stubs(:send_sms)
      .raises(MessageProviderService::ServerError, 'Provider returned 500: Internal Server Error')
    
    # Message is created and queued successfully
    assert_difference 'Message.count', 1 do
      post '/api/messages/sms', params: {
        from: '+12016661234',
        to: '+18045551234',
        type: 'sms',
        body: 'This will fail'
      }, as: :json
      
      assert_response :accepted  # 202 for queued messages
    end
    
    # Process the job to trigger the error
    perform_enqueued_jobs
    
    # Check that the message failed
    message = Message.last
    message.reload
    assert_equal 'failed', message.status
    assert_not_nil message.failed_at
    assert_includes message.error_message, 'Provider returned 500: Internal Server Error'
  end

  def test_invalid_message_data_handling
    post '/api/messages/sms', params: {
      from: '+12016661234',
      # missing required fields like 'to', 'body'
      type: 'sms'
    }, as: :json
    
    assert_response :unprocessable_content
    
    # Verify no message was created (conversation might be created but validation should fail)
    assert_equal 0, Message.count
  end

  def test_conversation_reuse_for_same_participants
    # Send first message
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'sms',
      body: 'First message'
    }, as: :json
    
    first_conversation_id = JSON.parse(response.body)['data']['conversation_id']
    
    # Send second message with same participants
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'sms',
      body: 'Second message'
    }, as: :json
    
    second_conversation_id = JSON.parse(response.body)['data']['conversation_id']
    
    # Verify same conversation is used
    assert_equal first_conversation_id, second_conversation_id
    
    # Verify conversation has both messages
    get "/api/conversations/#{first_conversation_id}/messages", as: :json
    
    messages = JSON.parse(response.body)['data']
    assert_equal 2, messages.length
  end

  def test_participant_order_normalization
    # Send message from A to B
    post '/api/messages/sms', params: {
      from: '+12016661234',
      to: '+18045551234',
      type: 'sms',
      body: 'Message from A to B'
    }, as: :json
    
    conversation_id_1 = JSON.parse(response.body)['data']['conversation_id']
    
    # Simulate incoming message from B to A (reversed participants)
    post '/api/webhooks/sms', params: {
      from: '+18045551234',
      to: '+12016661234',
      type: 'sms',
      messaging_provider_id: 'webhook-1',
      body: 'Reply from B to A'
    }, as: :json
    
    conversation_id_2 = JSON.parse(response.body)['data']['conversation_id']
    
    # Verify same conversation is used regardless of participant order
    assert_equal conversation_id_1, conversation_id_2
  end
end