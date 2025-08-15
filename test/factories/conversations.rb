FactoryBot.define do
  factory :conversation do
    participants { ['+12016661234', '+18045551234'] }
    
    # Transient attribute for message count
    transient do
      message_count { 0 }
    end
    
    trait :email_conversation do
      participants { ['user@usehatchapp.com', 'contact@gmail.com'] }
    end
    
    trait :with_messages do
      message_count { 3 } # Default to 3 messages
      
      after(:create) do |conversation, evaluator|
        create_list(:message, evaluator.message_count, conversation: conversation)
      end
    end
  end
end
