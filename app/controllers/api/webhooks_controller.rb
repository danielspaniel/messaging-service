class Api::WebhooksController < Api::BaseController
  # Receive SMS/MMS webhook
  def receive_sms
    webhook_params = sms_webhook_params
    
    # Create inbound message (directly delivered, no queue needed)
    sender_identifier = webhook_params[:from]
    recipient_identifier = webhook_params[:to]
    
    # Find or create conversation with message type
    message_type = webhook_params[:type]
    unless message_type.present?
      return render_error('type parameter is required', :bad_request)
    end
    conversation = Conversation.find_or_create_for_participants(sender_identifier, recipient_identifier, message_type)
    sender = Participant.find_or_create_by_identifier(sender_identifier)
    
    # Create message directly as delivered (no queue for incoming)
    message = Message.create!(
      conversation: conversation,
      sender: sender,
      message_type: message_type,
      body: webhook_params[:body],
      attachments: webhook_params[:attachments] || [],
      timestamp: webhook_params[:timestamp] || Time.current,
      status: 'delivered',  # Webhooks are already delivered
      provider_message_id: webhook_params[:provider_message_id]
    )
    
    Rails.logger.info "Received #{webhook_params[:type]&.upcase || 'UNKNOWN'} message: #{message.id} in conversation: #{message.conversation_id}"
    
    render_success(
      {
        message_id: message.id,
        conversation_id: message.conversation_id,
        status: 'received'
      },
      :created
    )
  end
  
  # Receive Email webhook
  def receive_email
    webhook_params = email_webhook_params
    
    # Create inbound email message (directly delivered, no queue needed)
    sender_identifier = webhook_params[:from]
    recipient_identifier = webhook_params[:to]
    
    # Find or create conversation with message type
    conversation = Conversation.find_or_create_for_participants(sender_identifier, recipient_identifier, 'email')
    sender = Participant.find_or_create_by_identifier(sender_identifier)
    
    # Create message directly as delivered (no queue for incoming)
    message = Message.create!(
      conversation: conversation,
      sender: sender,
      message_type: 'email',
      body: webhook_params[:body],
      attachments: webhook_params[:attachments] || [],
      timestamp: webhook_params[:timestamp] || Time.current,
      status: 'delivered',  # Webhooks are already delivered
      provider_message_id: webhook_params[:provider_message_id]
    )
    
    Rails.logger.info "Received Email message: #{message.id} in conversation: #{message.conversation_id}"
    
    render_success(
      {
        message_id: message.id,
        conversation_id: message.conversation_id,
        status: 'received'
      },
      :created
    )
  end
  
  private
  
  def sms_webhook_params
    if params[:webhook].present?
      # Handle wrapped parameters (e.g., { webhook: { from: "...", to: "..." } })
      params.require(:webhook).permit(:from, :to, :type, :body, :provider_message_id, :timestamp, attachments: [])
    else
      # Handle direct JSON parameters (e.g., { from: "...", to: "..." })
      params.permit(:from, :to, :type, :body, :provider_message_id, :timestamp, attachments: [])
    end
  end
  
  def email_webhook_params
    if params[:webhook].present?
      # Handle wrapped parameters (e.g., { webhook: { from: "...", to: "..." } })
      params.require(:webhook).permit(:from, :to, :body, :provider_message_id, :timestamp, attachments: [])
    else
      # Handle direct JSON parameters (e.g., { from: "...", to: "..." })
      params.permit(:from, :to, :body, :provider_message_id, :timestamp, attachments: [])
    end
  end
end
