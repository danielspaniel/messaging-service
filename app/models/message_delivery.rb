class MessageDelivery < ApplicationRecord
  belongs_to :message
  belongs_to :recipient, class_name: 'Participant'
  
  validates :status, presence: true, inclusion: { 
    in: %w[pending queued sending sent delivered failed] 
  }
  
  # Status scopes
  scope :pending, -> { where(status: 'pending') }
  scope :queued, -> { where(status: 'queued') }
  scope :sending, -> { where(status: 'sending') }
  scope :sent, -> { where(status: 'sent') }
  scope :delivered, -> { where(status: 'delivered') }
  scope :failed, -> { where(status: 'failed') }
  
  # Status management methods
  def mark_as_queued!
    update_columns(status: 'queued')
  end
  
  def mark_as_sending!
    update_columns(status: 'sending', sent_at: nil)
  end
  
  def mark_as_sent!(provider_id = nil)
    updates = { status: 'sent', sent_at: Time.current }
    updates[:provider_message_id] = provider_id if provider_id
    update_columns(updates)
    
    # Update message aggregate status
    message.update_aggregate_status!
  end
  
  def mark_as_delivered!
    update_columns(status: 'delivered')
    
    # Update message aggregate status
    message.update_aggregate_status!
  end
  
  def mark_as_failed!(error_message = nil)
    update_columns(
      status: 'failed', 
      failure_reason: error_message, 
      failed_at: Time.current,
      retry_count: self.retry_count + 1
    )
    
    # Update message aggregate status
    message.update_aggregate_status!
  end
end
