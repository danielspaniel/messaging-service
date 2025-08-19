class Api::MessagesController < Api::BaseController
  # Unified message creation endpoint
  def create
    message_params = unified_message_params
    
    # Handle conversation_id - if not provided, try to find/create from from/to
    conversation_id = message_params[:conversation_id]
    
    if conversation_id.present?
      # Using existing conversation - get message type from conversation
      begin
        conversation = Conversation.find(conversation_id)
        message_type = conversation.message_type
      rescue ActiveRecord::RecordNotFound
        return render_error('Conversation not found', :not_found)
      end
    else
      # Creating new conversation - type parameter is required
      unless message_params[:type].present?
        return render_error('type parameter is required when not using existing conversation_id', :bad_request)
      end
      
      unless %w[sms mms email].include?(message_params[:type])
        return render_error("Invalid message type: #{message_params[:type]}", :bad_request)
      end
      
      from = message_params[:from]
      to_participants = message_params[:to]
      
      unless from.present? && to_participants.present? && to_participants.any?
        return render_error('Both from and to parameters are required when not using existing conversation_id', :bad_request)
      end
      
      # Find or create conversation from all participants (sender + recipients)
      all_participants = [from] + to_participants
      message_type = message_params[:type]
      conversation = Conversation.find_or_create_for_participants(all_participants, message_type)
    end

    # Create message in conversation (will be queued automatically)
    begin
      message = Message.create_in_conversation!(
        conversation.id,
        sender: message_params[:from],
        message_type: message_type,  # Use message_type from conversation
        body: message_params[:body],
        attachments: message_params[:attachments] || [],
        timestamp: message_params[:timestamp] || Time.current
      )
    rescue ArgumentError => e
      return render_error(e.message, :bad_request)
    rescue ActiveRecord::RecordNotFound
      return render_error('Conversation not found', :not_found)
    end
    
    render_success(
      {
        message_id: message.id,
        conversation_id: message.conversation_id,
        status: message.status,
        status_url: "/api/messages/#{message.id}/status"
      },
      :created
    )
  end
  
  # Get status of a specific message
  def status
    message = Message.find(params[:id])
    
    # Get all recipients (all participants except sender)
    recipients = message.conversation.participants.where.not(id: message.sender.id).pluck(:identifier)
    
    render_success(
      {
        message_id: message.id,
        conversation_id: message.conversation_id,
        status: message.status,
        sender: message.sender.identifier,
        recipients: recipients,
        message_type: message.message_type,
        body: message.body,
        timestamp: message.timestamp,
        queued_at: message.queued_at,
        sent_at: message.sent_at,
        failed_at: message.failed_at,
        retry_count: message.retry_count,
        failure_reason: message.failure_reason,
        provider_message_id: message.provider_message_id,
        status_url: "/api/messages/#{message.id}/status"
      }
    )
  rescue ActiveRecord::RecordNotFound
    render_error('Message not found', :not_found)
  end
  
  private
  
  def unified_message_params
    # Handle all message types with a single parameter method
    # 'to' can be a single string or an array of strings
    permitted = params.permit(:from, :type, :body, :timestamp, :conversation_id, attachments: [], to: [])
    
    # Handle 'to' parameter - could be string or array
    if params[:to].is_a?(Array)
      permitted[:to] = params[:to]
    elsif params[:to].present?
      permitted[:to] = [params[:to]] # Convert single value to array for consistency
    end
    
    permitted
  end
end