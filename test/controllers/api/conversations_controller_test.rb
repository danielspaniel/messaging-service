require "test_helper"

class Api::ConversationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @conversation1 = create(:conversation, :with_messages, participant_identifiers: ['+12016661234', '+18045551234'])
    @conversation2 = create(:conversation, :email_conversation, participant_identifiers: ['user@example.com', 'contact@example.com'])
    create(:message, :email, conversation: @conversation2)
  end

  def test_index_returns_all_conversations
    get '/api/conversations', as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 2, json_response['data'].length
    conversation_data = json_response['data'].first
    assert_equal conversation_data.keys, ["id", "participants", "created_at",
                                          "updated_at", "message_count", "last_message"]
  end

  def test_index_includes_last_message_details_when_messages_exist
    get '/api/conversations', as: :json

    json_response = JSON.parse(response.body)
    conversation_with_messages = json_response['data'].find { |c| c['message_count'] > 0 }

    assert_not_nil conversation_with_messages['last_message']
    assert_includes conversation_with_messages['last_message'], 'id'
    assert_includes conversation_with_messages['last_message'], 'body'
    assert_includes conversation_with_messages['last_message'], 'timestamp'
    assert_includes conversation_with_messages['last_message'], 'sender'
    assert_includes conversation_with_messages['last_message'], 'message_type'
  end

  def test_index_orders_conversations_by_updated_at_descending
    # Update one conversation to change its updated_at
    @conversation1.update_attribute(:updated_at, Time.current)

    get '/api/conversations', as: :json

    json_response = JSON.parse(response.body)
    conversation_ids = json_response['data'].map { |c| c['id'] }

    # The latest conversation should be first
    assert_equal @conversation1.id, conversation_ids.first
  end

  def test_show_returns_specific_conversation
    get "/api/conversations/#{@conversation1.id}", as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal @conversation1.id, json_response['data']['id']
  end

  def test_show_includes_conversation_details
    get "/api/conversations/#{@conversation1.id}", as: :json

    json_response = JSON.parse(response.body)
    conversation_data = json_response['data']

    assert_equal @conversation1.id, conversation_data['id']
    assert_equal @conversation1.participants.pluck(:identifier), conversation_data['participants']
    assert_equal @conversation1.messages.count, conversation_data['message_count']
  end

  def test_show_returns_not_found_for_invalid_conversation
    get "/api/conversations/99999", as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal 'Not found', json_response['error']
  end

  def test_messages_returns_messages_for_conversation_ordered_by_timestamp
    conversation = create(:conversation)
    message1 = create(:message, conversation: conversation, timestamp: 2.hours.ago)
    message2 = create(:message, conversation: conversation, timestamp: 1.hour.ago)
    message3 = create(:message, conversation: conversation, timestamp: 30.minutes.ago)

    get "/api/conversations/#{conversation.id}/messages", as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 3, json_response['data'].length

    ids = json_response['data'].map { |m| m['id'] }
    assert_equal ids, [message1.id, message2.id, message3.id]
  end

  def test_messages_includes_complete_message_details
    conversation = create(:conversation)
    create(:message, conversation: conversation)

    get "/api/conversations/#{conversation.id}/messages", as: :json

    json_response = JSON.parse(response.body)
    message_data = json_response['data'].first

    assert_includes message_data, 'id'
    assert_includes message_data, 'conversation_id'
    assert_includes message_data, 'sender'
    assert_includes message_data, 'message_type'
    assert_includes message_data, 'body'
    assert_includes message_data, 'attachments'
    assert_includes message_data, 'timestamp'
    assert_includes message_data, 'provider_message_id'
    assert_includes message_data, 'created_at'
  end

  def test_messages_returns_empty_array_for_conversation_with_no_messages
    empty_conversation = create(:conversation)

    get "/api/conversations/#{empty_conversation.id}/messages", as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 0, json_response['data'].length
  end

  def test_messages_returns_not_found_for_invalid_conversation
    get "/api/conversations/99999/messages", as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal 'Not found', json_response['error']
  end

  def test_create_new_conversation
    participants = ['+15551234567', '+15559876543']  # Different participants
    
    assert_difference 'Conversation.count', 1 do
      post '/api/conversations', params: {
        participants: participants,
        message_type: 'sms'
      }, as: :json
    end
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response['success']
    
    conversation_data = json_response['data']
    assert_equal participants.sort, conversation_data['participants'].sort
    assert_equal 0, conversation_data['message_count']
  end

  def test_create_finds_existing_conversation
    # Use different participants to avoid conflicts with setup
    participants = ['+15551111111', '+15552222222']
    existing_conversation = create(:conversation, participant_identifiers: participants, message_type: 'sms')
    
    assert_no_difference 'Conversation.count' do
      post '/api/conversations', params: {
        participants: participants,
        message_type: 'sms'
      }, as: :json
    end
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal existing_conversation.id, json_response['data']['id']
  end

  def test_create_requires_participants_array
    post '/api/conversations', params: {
      participants: 'not-an-array',
      message_type: 'sms'
    }, as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_match(/participants must be an array/, json_response['error'])
  end

  def test_create_requires_at_least_two_participants
    post '/api/conversations', params: {
      participants: ['+12016661234'],
      message_type: 'sms'
    }, as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_match(/at least 2 members/, json_response['error'])
  end

  def test_create_requires_message_type
    post '/api/conversations', params: {
      participants: ['+12016661234', '+18045551234']
    }, as: :json
    
    assert_response :internal_server_error  # Rails throws 500 for missing required params
    json_response = JSON.parse(response.body)
    assert_match(/message_type/, json_response['message'])
  end
end