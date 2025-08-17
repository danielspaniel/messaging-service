class SendMessageJob < ApplicationJob
  queue_as :default
  
  def perform(message_id)
    message = Message.find(message_id)
    
    Rails.logger.info "Processing message #{message_id}"
    
    # Mark as sending
    message.mark_as_sending!
    
    begin
      # Send via provider based on message type
      provider_response = case message.message_type
                         when 'sms'
                           MessageProviderService.send_sms(message_params_for_provider(message))
                         when 'mms'
                           MessageProviderService.send_mms(message_params_for_provider(message))
                         when 'email'
                           MessageProviderService.send_email(message_params_for_provider(message))
                         else
                           raise "Unknown message type: #{message.message_type}"
                         end
      
      # Mark as sent with provider ID
      message.mark_as_sent!(provider_response[:provider_id])
      
      Rails.logger.info "Successfully sent message #{message_id}, provider_id: #{provider_response[:provider_id]}"
      
    rescue MessageProviderService::ProviderError => e
      Rails.logger.error "Provider error for message #{message_id}: #{e.message}"
      message.mark_as_failed!(e.message)
      # Don't re-raise - we've handled the error
      
    rescue => e
      Rails.logger.error "Unexpected error for message #{message_id}: #{e.message}"
      message.mark_as_failed!(e.message)
      # Don't re-raise - we've handled the error
    end
  end
  
  private
  
  def message_params_for_provider(message)
    {
      from: message.from,
      to: message.to,
      type: message.message_type,
      body: message.body,
      attachments: message.attachments || [],
      timestamp: message.timestamp
    }
  end
end
