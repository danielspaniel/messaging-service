require "test_helper"

class Api::ConversationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @conversation1 = create(:conversation, :with_messages)
    @conversation2 = create(:conversation, :email_conversation)
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
    assert_includes conversation_with_messages['last_message'], 'direction'
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
    assert_equal @conversation1.participants, conversation_data['participants']
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
    message3 = create(:message, :inbound, conversation: conversation, timestamp: 30.minutes.ago)

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
    assert_includes message_data, 'from'
    assert_includes message_data, 'to'
    assert_includes message_data, 'message_type'
    assert_includes message_data, 'body'
    assert_includes message_data, 'attachments'
    assert_includes message_data, 'timestamp'
    assert_includes message_data, 'direction'
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
end