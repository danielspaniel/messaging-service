FactoryBot.define do
  factory :conversation do
    message_type { 'sms' }
    
    # Transient attributes for participants
    transient do
      participant_identifiers { ['+12016661234', '+18045551234'] }
      message_count { 0 }
    end
    
    # Create participants after conversation is built
    after(:create) do |conversation, evaluator|
      evaluator.participant_identifiers.each do |identifier|
        participant = Participant.find_or_create_by(identifier: identifier)
        create(:conversation_participant, conversation: conversation, participant: participant)
      end
    end
    
    trait :email_conversation do
      message_type { 'email' }
      participant_identifiers { ['user@usehatchapp.com', 'contact@gmail.com'] }
    end
    
    trait :with_messages do
      message_count { 3 } # Default to 3 messages
      
      after(:create) do |conversation, evaluator|
        create_list(:message, evaluator.message_count, conversation: conversation)
      end
    end
  end
end
