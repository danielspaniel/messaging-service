FactoryBot.define do
  factory :message_delivery do
    association :message
    association :recipient, factory: :participant
    status { 'pending' }
    provider_message_id { nil }
    sent_at { nil }
    failed_at { nil }
    failure_reason { nil }
    retry_count { 0 }
    
    trait :queued do
      status { 'queued' }
    end
    
    trait :sending do
      status { 'sending' }
    end
    
    trait :sent do
      status { 'sent' }
      sent_at { Time.current }
      provider_message_id { 'provider_123' }
    end
    
    trait :delivered do
      status { 'delivered' }
      sent_at { Time.current }
      provider_message_id { 'provider_123' }
    end
    
    trait :failed do
      status { 'failed' }
      failed_at { Time.current }
      failure_reason { 'Provider error' }
      retry_count { 1 }
    end
  end
end
