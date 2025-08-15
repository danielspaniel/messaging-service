class MessageProviderService
  class ProviderError < StandardError
    attr_reader :status_code
    
    def initialize(message, status_code = 500)
      super(message)
      @status_code = status_code
    end
  end
  
  class RateLimitError < ProviderError
    def initialize(message = "Rate limit exceeded")
      super(message, 429)
    end
  end
  
  class ServerError < ProviderError
    def initialize(message = "Provider server error")
      super(message, 500)
    end
  end
  
  def self.send_sms(message_params)
    # In real implementation, this would make an actual API call to SMS provider
    # For now, we'll just return a mock response
    {
      provider_id: "sms_provider",
      status: 'sent',
      provider: 'sms_provider'
    }
  end
  
  def self.send_mms(message_params)
    # In real implementation, this would make an actual API call to MMS provider
    # For now, we'll just return a mock response
    {
      provider_id: "mms_provider",
      status: 'sent',
      provider: 'mms_provider'
    }
  end
  
  def self.send_email(message_params)
    # In real implementation, this would make an actual API call to email provider
    # For now, we'll just return a mock response
    {
      provider_id: "email_provider",
      status: 'sent',
      provider: 'email_provider'
    }
  end
end
