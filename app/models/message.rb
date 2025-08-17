class Message < ApplicationRecord
  belongs_to :conversation
  
  validates :from, presence: true
  validates :to, presence: true
  validates :message_type, presence: true, inclusion: { in: %w[sms mms email] }
  validates :body, presence: true
  validates :timestamp, presence: true
  validates :direction, presence: true, inclusion: { in: %w[inbound outbound] }
  validates :status, presence: true, inclusion: { 
    in: %w[pending queued sending sent delivered failed] 
  }
  
  # Serialize attachments as an array
  serialize :attachments, coder: YAML
  
  scope :ordered, -> { order(:timestamp) }
  scope :inbound, -> { where(direction: 'inbound') }
  scope :outbound, -> { where(direction: 'outbound') }
  
  # Status scopes
  scope :pending, -> { where(status: 'pending') }
  scope :queued, -> { where(status: 'queued') }
  scope :sending, -> { where(status: 'sending') }
  scope :sent, -> { where(status: 'sent') }
  scope :delivered, -> { where(status: 'delivered') }
  scope :failed, -> { where(status: 'failed') }
  
  # Create a message and automatically assign it to a conversation
  def self.create_with_conversation!(attributes)
    from = attributes[:from]
    to = attributes[:to]
    
    # Find or create conversation
    conversation = Conversation.find_or_create_for_participants(from, to)
    
    # Create message
    create!(attributes.merge(conversation: conversation))
  end
  
  def provider_message_id
    case message_type
    when 'sms', 'mms'
      messaging_provider_id
    when 'email'
      xillio_id
    end
  end
  
  # Status transition methods
  def mark_as_queued!
    update!(status: 'queued', queued_at: Time.current)
  end
  
  def mark_as_sending!
    update!(status: 'sending')
  end
  
  def mark_as_sent!(provider_id = nil)
    attributes = { status: 'sent', sent_at: Time.current }
    
    # Update provider ID based on message type
    case message_type
    when 'sms', 'mms'
      attributes[:messaging_provider_id] = provider_id if provider_id
    when 'email'
      attributes[:xillio_id] = provider_id if provider_id
    end
    
    update!(attributes)
  end
  
  def mark_as_failed!(error_message = nil)
    update!(
      status: 'failed',
      failed_at: Time.current,
      error_message: error_message,
      retry_count: retry_count + 1
    )
  end
  
  def mark_as_delivered!
    update!(status: 'delivered')
  end
  
  # Status check methods
  def pending?
    status == 'pending'
  end
  
  def queued?
    status == 'queued'
  end
  
  def sent?
    status == 'sent'
  end
  
  def failed?
    status == 'failed'
  end
  
  def can_retry?
    failed? && retry_count < 3
  end
end
