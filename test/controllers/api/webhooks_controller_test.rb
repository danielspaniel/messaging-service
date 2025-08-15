require "test_helper"

class Api::WebhooksControllerTest < ActionDispatch::IntegrationTest
  def setup
    @valid_sms_webhook = {
      from: '+18045551234',
      to: '+12016661234',
      type: 'sms',
      messaging_provider_id: 'message-1',
      body: 'This is an incoming SMS message',
      timestamp: '2024-11-01T14:00:00Z'
    }

    @valid_mms_webhook = {
      from: '+18045551234',
      to: '+12016661234',
      type: 'mms',
      messaging_provider_id: 'message-2',
      body: 'This is an incoming MMS message',
      attachments: ['https://example.com/received-image.jpg'],
      timestamp: '2024-11-01T14:00:00Z'
    }

    @valid_email_webhook = {
      from: 'contact@gmail.com',
      to: 'user@usehatchapp.com',
      xillio_id: 'message-3',
      body: '<html><body>This is an incoming email with <b>HTML</b> content</body></html>',
      attachments: ['https://example.com/received-document.pdf'],
      timestamp: '2024-11-01T14:00:00Z'
    }
  end

  def test_receive_sms_creates_new_inbound_sms_message
    assert_difference 'Message.count', 1 do
      post '/api/webhooks/sms', params: @valid_sms_webhook, as: :json
    end
  end

  def test_receive_sms_creates_new_conversation_if_none_exists
    assert_difference 'Conversation.count', 1 do
      post '/api/webhooks/sms', params: @valid_sms_webhook, as: :json
    end
  end

  def test_receive_sms_returns_success_response
    post '/api/webhooks/sms', params: @valid_sms_webhook, as: :json
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_includes json_response['data'], 'message_id'
    assert_includes json_response['data'], 'conversation_id'
    assert_includes json_response['data'], 'status'
  end

  def test_receive_sms_sets_correct_message_attributes
    post '/api/webhooks/sms', params: @valid_sms_webhook, as: :json
    
    message = Message.last
    assert_equal @valid_sms_webhook[:from], message.from
    assert_equal @valid_sms_webhook[:to], message.to
    assert_equal @valid_sms_webhook[:type], message.message_type
    assert_equal @valid_sms_webhook[:body], message.body
    assert_equal 'inbound', message.direction
    assert_equal @valid_sms_webhook[:messaging_provider_id], message.messaging_provider_id
  end

  def test_receive_sms_creates_mms_message_with_attachments
    post '/api/webhooks/sms', params: @valid_mms_webhook, as: :json
    
    message = Message.last
    assert_equal 'mms', message.message_type
    assert_equal ['https://example.com/received-image.jpg'], message.attachments
    assert_equal 'inbound', message.direction
  end

  def test_receive_sms_uses_existing_conversation
    existing_conversation = Conversation.find_or_create_for_participants(
      @valid_sms_webhook[:from], 
      @valid_sms_webhook[:to]
    )
    
    assert_difference 'Message.count', 1 do
      assert_no_difference 'Conversation.count' do
        post '/api/webhooks/sms', params: @valid_sms_webhook, as: :json
      end
    end
    
    message = Message.last
    assert_equal existing_conversation, message.conversation
  end

  def test_receive_email_creates_new_inbound_email_message
    assert_difference 'Message.count', 1 do
      post '/api/webhooks/email', params: @valid_email_webhook, as: :json
    end
  end

  def test_receive_email_returns_success_response
    post '/api/webhooks/email', params: @valid_email_webhook, as: :json
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response['success']
  end

  def test_receive_email_sets_correct_email_attributes
    post '/api/webhooks/email', params: @valid_email_webhook, as: :json
    
    message = Message.last
    assert_equal 'email', message.message_type
    assert_equal 'inbound', message.direction
    assert_equal @valid_email_webhook[:xillio_id], message.xillio_id
    assert_nil message.messaging_provider_id
  end

  def test_receive_sms_handles_validation_errors_gracefully
    post '/api/webhooks/sms', params: { from: '+18045551234' }, as: :json # missing required fields
    
    assert_response :unprocessable_content
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
  end
end