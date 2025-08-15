class Api::MessagesController < Api::BaseController
  # Send SMS/MMS message
  def send_sms
    message_params = sms_message_params
    
    # Validate required parameters
    unless message_params[:type].present?
      return render_error('Missing message type', :bad_request)
    end
    
    unless %w[sms mms].include?(message_params[:type])
      return render_error("Invalid message type: #{message_params[:type]}", :bad_request)
    end
    
    # Send message via provider
    provider_response = case message_params[:type]
                       when 'sms'
                         MessageProviderService.send_sms(message_params)
                       when 'mms'
                         MessageProviderService.send_mms(message_params)
                       end
    
    # Create outbound message
    message = Message.create_with_conversation!(
      from: message_params[:from],
      to: message_params[:to],
      message_type: message_params[:type],
      body: message_params[:body],
      attachments: message_params[:attachments] || [],
      timestamp: message_params[:timestamp] || Time.current,
      direction: 'outbound',
      messaging_provider_id: provider_response[:provider_id]
    )
    
    render_success(
      {
        message_id: message.id,
        provider_id: message.messaging_provider_id,
        conversation_id: message.conversation_id,
        status: 'sent'
      },
      :created
    )
  end
  
  # Send Email message
  def send_email
    message_params = email_message_params
    
    # Send email via provider
    provider_response = MessageProviderService.send_email(message_params)
    
    # Create outbound message
    message = Message.create_with_conversation!(
      from: message_params[:from],
      to: message_params[:to],
      message_type: 'email',
      body: message_params[:body],
      attachments: message_params[:attachments] || [],
      timestamp: message_params[:timestamp] || Time.current,
      direction: 'outbound',
      xillio_id: provider_response[:provider_id]
    )
    
    render_success(
      {
        message_id: message.id,
        provider_id: message.xillio_id,
        conversation_id: message.conversation_id,
        status: 'sent'
      },
      :created
    )
  end
  
  private
  
  def sms_message_params
    # Handle direct JSON without wrapper (which is how tests send it)
    params.permit(:from, :to, :type, :body, :timestamp, attachments: [])
  end
  
  def email_message_params
    # Handle direct JSON without wrapper (which is how tests send it)
    params.permit(:from, :to, :body, :timestamp, attachments: [])
  end
  
  def generate_provider_id
    "msg_#{SecureRandom.hex(8)}_#{Time.current.to_i}"
  end
end
