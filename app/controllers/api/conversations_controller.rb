class Api::ConversationsController < Api::BaseController
  # Get all conversations
  def index
    conversations = Conversation.includes({ messages: :sender }, :participants)
                               .order(updated_at: :desc)
                               .limit(100)
    
    conversations_data = conversations.map do |conversation|
      last_message = conversation.messages.ordered.last
      
      {
        id: conversation.id,
        participants: conversation.participants.pluck(:identifier),
        created_at: conversation.created_at,
        updated_at: conversation.updated_at,
        message_count: conversation.messages.count,
        last_message: last_message ? {
          id: last_message.id,
          body: last_message.body.truncate(100),
          timestamp: last_message.timestamp,
          sender: last_message.sender.identifier,
          message_type: last_message.message_type
        } : nil
      }
    end
    
    render_success(conversations_data)
  end
  
  # Get specific conversation
  def show
    conversation = Conversation.includes(:participants).find(params[:id])
    
    conversation_data = {
      id: conversation.id,
      participants: conversation.participants.pluck(:identifier),
      created_at: conversation.created_at,
      updated_at: conversation.updated_at,
      message_count: conversation.messages.count
    }
    
    render_success(conversation_data)
  end
  
  # Create a new conversation
  def create
    participants = params.require(:participants)
    message_type = params.require(:message_type)
    
    unless participants.is_a?(Array) && participants.length >= 2
      return render_error('participants must be an array with at least 2 members', :bad_request)
    end
    
    unless %w[sms mms email].include?(message_type)
      return render_error("Invalid message type: #{message_type}", :bad_request)
    end
    
    # Create conversation with participants and type
    conversation = Conversation.find_or_create_for_participants(participants, message_type)
    
    conversation_data = {
      id: conversation.id,
      participants: conversation.participants.pluck(:identifier),
      created_at: conversation.created_at,
      updated_at: conversation.updated_at,
      message_count: 0
    }
    
    render_success(conversation_data, :created)
  end
  
  # Get messages for a conversation
  def messages
    conversation = Conversation.find(params[:id])
    messages = conversation.messages.ordered.includes(:sender, :conversation)
    
    messages_data = messages.map do |message|
      {
        id: message.id,
        conversation_id: message.conversation_id,
        sender: message.sender.identifier,
        message_type: message.message_type,
        body: message.body,
        attachments: message.attachments,
        timestamp: message.timestamp,
        provider_message_id: message.provider_message_id,
        created_at: message.created_at
      }
    end
    
    render_success(messages_data)
  end
end
