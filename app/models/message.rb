class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: 'Participant'
  has_many :message_deliveries, dependent: :destroy
  # For 1-to-1 conversations, recipient is derived from conversation participants
  validates :sender, presence: true
  validates :message_type, presence: true, inclusion: { in: %w[sms mms email] }
  validates :body, presence: true
  validates :timestamp, presence: true
  validates :status, presence: true, inclusion: { 
    in: %w[pending queued sending sent delivered failed partial] 
  }
  
  # For 1-to-1 conversations, we derive recipient from conversation participants
  
  # Serialize attachments as an array
  serialize :attachments, coder: YAML
  
  scope :ordered, -> { order(:timestamp) }
  
  # Status scopes
  scope :pending, -> { where(status: 'pending') }
  scope :queued, -> { where(status: 'queued') }
  scope :sending, -> { where(status: 'sending') }
  scope :sent, -> { where(status: 'sent') }
  scope :delivered, -> { where(status: 'delivered') }
  scope :failed, -> { where(status: 'failed') }
  
  # Create message in a conversation and queue for delivery
  def self.create_in_conversation!(conversation_id, attributes)
    conversation = Conversation.find(conversation_id)
    sender_identifier = attributes[:sender] || attributes[:from]
    sender = Participant.find_or_create_by_identifier(sender_identifier)
    
    # Verify sender is part of this conversation
    unless conversation.participants.include?(sender)
      raise ArgumentError, "Sender #{sender_identifier} is not a participant in conversation #{conversation_id}"
    end
    
    # Create message (clean attributes, set defaults)
    message_attributes = attributes.except(:from, :to, :sender).merge(
      conversation: conversation,
      sender: sender,
      status: 'pending'
    )
    
    message = create!(message_attributes)
    
    # Create delivery records for each recipient (excluding sender)
    recipients = conversation.participants.where.not(id: sender.id)
    recipients.each do |recipient|
      delivery = message.message_deliveries.create!(
        recipient: recipient,
        status: 'pending'
      )
      
      # Queue delivery job for this specific delivery
      SendMessageJob.perform_later(message.id, delivery.id)
    end
    
    message.update!(status: 'sending', queued_at: Time.current)
    
    message
  end
    
  # Update message status based on delivery statuses
  def update_aggregate_status!
    statuses = message_deliveries.pluck(:status)
    return if statuses.empty?
    
    new_status = case
                 when statuses.all?('delivered')
                   'delivered'
                 when statuses.all? { |s| s.in?(['sent', 'delivered']) }
                   'sent'
                 when statuses.any?('failed') && statuses.any? { |s| s.in?(['sent', 'delivered']) }
                   'partial'
                 when statuses.all?('failed')
                   'failed'
                 else
                   'sending'
                 end
    
    update_columns(status: new_status)
  end
end