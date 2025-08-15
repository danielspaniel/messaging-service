class Api::ConversationsController < Api::BaseController
  # Get all conversations
  def index
    conversations = Conversation.includes(:messages)
                               .order(updated_at: :desc)
                               .limit(100)
    
    conversations_data = conversations.map do |conversation|
      last_message = conversation.messages.ordered.last
      
      {
        id: conversation.id,
        participants: conversation.participants,
        created_at: conversation.created_at,
        updated_at: conversation.updated_at,
        message_count: conversation.messages.count,
        last_message: last_message ? {
          id: last_message.id,
          body: last_message.body.truncate(100),
          timestamp: last_message.timestamp,
          direction: last_message.direction,
          message_type: last_message.message_type
        } : nil
      }
    end
    
    render_success(conversations_data)
  end
  
  # Get specific conversation
  def show
    conversation = Conversation.find(params[:id])
    
    conversation_data = {
      id: conversation.id,
      participants: conversation.participants,
      created_at: conversation.created_at,
      updated_at: conversation.updated_at,
      message_count: conversation.messages.count
    }
    
    render_success(conversation_data)
  end
  
  # Get messages for a conversation
  def messages
    conversation = Conversation.find(params[:id])
    messages = conversation.messages.ordered.includes(:conversation)
    
    messages_data = messages.map do |message|
      {
        id: message.id,
        conversation_id: message.conversation_id,
        from: message.from,
        to: message.to,
        message_type: message.message_type,
        body: message.body,
        attachments: message.attachments,
        timestamp: message.timestamp,
        direction: message.direction,
        provider_message_id: message.provider_message_id,
        created_at: message.created_at
      }
    end
    
    render_success(messages_data)
  end
end
