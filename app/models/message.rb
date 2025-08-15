class Message < ApplicationRecord
  belongs_to :conversation
  
  validates :from, presence: true
  validates :to, presence: true
  validates :message_type, presence: true, inclusion: { in: %w[sms mms email] }
  validates :body, presence: true
  validates :timestamp, presence: true
  validates :direction, presence: true, inclusion: { in: %w[inbound outbound] }
  
  # Serialize attachments as an array
  serialize :attachments, coder: YAML
  
  scope :ordered, -> { order(:timestamp) }
  scope :inbound, -> { where(direction: 'inbound') }
  scope :outbound, -> { where(direction: 'outbound') }
  
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
end
