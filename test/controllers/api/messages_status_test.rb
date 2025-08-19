require "test_helper"

class Api::MessagesStatusTest < ActionDispatch::IntegrationTest
  def setup
    @conversation = create(:conversation, participant_identifiers: ['+12016661234', '+18045551234'])
    @sender = Participant.find_by(identifier: '+12016661234')
    @message = create(:message, 
      conversation: @conversation, 
      sender: @sender, 
      status: 'sent',
      provider_message_id: 'test_provider_123'
    )
  end

  def test_status_endpoint_returns_message_details
    get "/api/messages/#{@message.id}/status", as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert json_response['success']
    data = json_response['data']
    
    assert_equal @message.id, data['message_id']
    assert_equal @conversation.id, data['conversation_id']
    assert_equal 'sent', data['status']
    assert_equal '+12016661234', data['sender']
    assert_equal ['+18045551234'], data['recipients']
    assert_equal @message.message_type, data['message_type']
    assert_equal @message.body, data['body']
    assert_not_nil data['timestamp']
    assert_equal 'test_provider_123', data['provider_message_id']
  end

  def test_status_endpoint_not_found_for_invalid_message
    get "/api/messages/99999/status", as: :json
    
    assert_response :not_found
    json_response = JSON.parse(response.body)
    
    assert_equal false, json_response['success']
    assert_equal 'Message not found', json_response['error']
  end

  def test_unified_create_includes_status_urls
    post '/api/messages', params: {
      conversation_id: @conversation.id,
      from: '+12016661234',
      type: 'sms',
      body: 'Test message with status URLs',
      timestamp: '2024-11-01T15:00:00Z'
    }, as: :json
    
    assert_response :created
    json_response = JSON.parse(response.body)
    
    assert json_response['success']
    data = json_response['data']
    
    assert_includes data, 'status_url'
    
    # Verify status URL format
    assert data['status_url'].start_with?('/api/messages/')
    assert data['status_url'].end_with?('/status')
  end
end
