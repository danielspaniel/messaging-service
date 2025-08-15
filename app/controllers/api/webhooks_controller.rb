class Api::WebhooksController < Api::BaseController
  # Receive SMS/MMS webhook
  def receive_sms
    webhook_params = sms_webhook_params
    
    # Create inbound message
    message = Message.create_with_conversation!(
      from: webhook_params[:from],
      to: webhook_params[:to],
      message_type: webhook_params[:type],
      body: webhook_params[:body],
      attachments: webhook_params[:attachments] || [],
      timestamp: webhook_params[:timestamp] || Time.current,
      direction: 'inbound',
      messaging_provider_id: webhook_params[:messaging_provider_id]
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
    
    # Create inbound message
    message = Message.create_with_conversation!(
      from: webhook_params[:from],
      to: webhook_params[:to],
      message_type: 'email',
      body: webhook_params[:body],
      attachments: webhook_params[:attachments] || [],
      timestamp: webhook_params[:timestamp] || Time.current,
      direction: 'inbound',
      xillio_id: webhook_params[:xillio_id]
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
      params.require(:webhook).permit(:from, :to, :type, :body, :messaging_provider_id, :timestamp, attachments: [])
    else
      # Handle direct JSON parameters (e.g., { from: "...", to: "..." })
      params.permit(:from, :to, :type, :body, :messaging_provider_id, :timestamp, attachments: [])
    end
  end
  
  def email_webhook_params
    if params[:webhook].present?
      # Handle wrapped parameters (e.g., { webhook: { from: "...", to: "..." } })
      params.require(:webhook).permit(:from, :to, :body, :xillio_id, :timestamp, attachments: [])
    else
      # Handle direct JSON parameters (e.g., { from: "...", to: "..." })
      params.permit(:from, :to, :body, :xillio_id, :timestamp, attachments: [])
    end
  end
end
