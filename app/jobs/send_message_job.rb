class SendMessageJob < ApplicationJob
  queue_as :default
  
  def perform(message_id, delivery_id)
    message = Message.find(message_id)
    delivery = MessageDelivery.find(delivery_id)
    
    Rails.logger.info "Processing message #{message_id} delivery #{delivery_id} for recipient #{delivery.recipient.identifier}"
    deliver_to_recipient(message, delivery)
  end
  
  private
  
  def deliver_to_recipient(message, delivery)
    # Mark delivery as sending
    delivery.mark_as_sending!
    
    begin
      # Send to the specific recipient
      provider_response = case message.message_type
                         when 'sms'
                           MessageProviderService.send_sms(message_params_for_provider(message, delivery.recipient))
                         when 'mms'
                           MessageProviderService.send_mms(message_params_for_provider(message, delivery.recipient))
                         when 'email'
                           MessageProviderService.send_email(message_params_for_provider(message, delivery.recipient))
                         else
                           raise "Unknown message type: #{message.message_type}"
                         end
      
      # Mark delivery as sent
      delivery.mark_as_sent!(provider_response[:provider_id])
      
      Rails.logger.info "Successfully sent message #{message.id} to #{delivery.recipient.identifier}, provider_id: #{provider_response[:provider_id]}"
      
    rescue MessageProviderService::ProviderError => e
      Rails.logger.error "Provider error for message #{message.id} to #{delivery.recipient.identifier}: #{e.message}"
      delivery.mark_as_failed!(e.message)
      # Don't re-raise - we've handled the error
      
    rescue => e
      Rails.logger.error "Unexpected error for message #{message.id} to #{delivery.recipient.identifier}: #{e.message}"
      delivery.mark_as_failed!(e.message)
      # Don't re-raise - we've handled the error
    end
  end
  

  
  def message_params_for_provider(message, recipient)
    {
      from: message.sender.identifier,
      to: recipient.identifier,
      type: message.message_type,
      body: message.body,
      attachments: message.attachments || [],
      timestamp: message.timestamp
    }
  end
end
