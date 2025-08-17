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
        # Create message record first (in pending status)
    message = Message.create_with_conversation!(
      from: message_params[:from],
      to: message_params[:to],
      message_type: message_params[:type],
      body: message_params[:body],
      attachments: message_params[:attachments] || [],
      timestamp: message_params[:timestamp] || Time.current,
      direction: 'outbound',
      status: 'pending'
    )

    # Queue the message for background processing
    message.mark_as_queued!
    SendMessageJob.perform_later(message.id)

    render_success(
      {
        message_id: message.id,
        conversation_id: message.conversation_id,
        status: 'queued',
        status_url: "/api/messages/#{message.id}/status"
      },
      :accepted  # 202 Accepted instead of 201 Created
    )
  end
  
  # Send Email message
  def send_email
    message_params = email_message_params
    
    # Create message record first (in pending status)
    message = Message.create_with_conversation!(
      from: message_params[:from],
      to: message_params[:to],
      message_type: 'email',
      body: message_params[:body],
      attachments: message_params[:attachments] || [],
      timestamp: message_params[:timestamp] || Time.current,
      direction: 'outbound',
      status: 'pending'
    )

    # Queue the message for background processing
    message.mark_as_queued!
    SendMessageJob.perform_later(message.id)

    render_success(
      {
        message_id: message.id,
        conversation_id: message.conversation_id,
        status: 'queued',
        status_url: "/api/messages/#{message.id}/status"
      },
      :accepted  # 202 Accepted instead of 201 Created
    )
  end
  
  # Get message details
  def show
    message = Message.find(params[:id])
    
    render_success({
      id: message.id,
      conversation_id: message.conversation_id,
      from: message.from,
      to: message.to,
      message_type: message.message_type,
      body: message.body,
      status: message.status,
      direction: message.direction,
      created_at: message.created_at,
      queued_at: message.queued_at,
      sent_at: message.sent_at,
      failed_at: message.failed_at,
      error_message: message.error_message,
      retry_count: message.retry_count,
      provider_message_id: message.provider_message_id
    })
  end
  
  # Get just the status (lighter endpoint)
  def status
    message = Message.find(params[:id])
    
    render_success({
      id: message.id,
      status: message.status,
      created_at: message.created_at,
      queued_at: message.queued_at,
      sent_at: message.sent_at,
      failed_at: message.failed_at,
      retry_count: message.retry_count,
      error_message: message.error_message
    })
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
