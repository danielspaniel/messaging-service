class Participant < ApplicationRecord
  has_many :conversation_participants, dependent: :destroy
  has_many :conversations, through: :conversation_participants
  
  validates :identifier, presence: true, uniqueness: true
  
  # Find or create a participant by identifier
  def self.find_or_create_by_identifier(identifier)
    find_or_create_by(identifier: identifier.to_s)
  end
  
  # For factories and display
  def to_s
    identifier
  end
end
