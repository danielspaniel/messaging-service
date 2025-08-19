FactoryBot.define do
  factory :message do
    association :conversation
    association :sender, factory: :participant

    message_type { 'sms' }
    body { 'This is a test message' }
    attachments { [] }
    timestamp { Time.current }
    status { 'pending' }
    provider_message_id { "msg_#{SecureRandom.hex(8)}" }
    
    trait :from_different_sender do
      association :sender, factory: :participant, identifier: '+18045551234'
    end
    
    trait :mms do
      message_type { 'mms' }
      attachments { ['https://example.com/image.jpg'] }
    end
    
    trait :email do
      message_type { 'email' }
      association :sender, factory: :participant, identifier: 'user@usehatchapp.com'
      body { '<html><body>This is an <b>HTML</b> email</body></html>' }
      provider_message_id { "email_#{SecureRandom.hex(8)}" }
    end
    
    trait :with_attachments do
      attachments { ['https://example.com/file1.pdf', 'https://example.com/file2.jpg'] }
    end
    
    trait :queued do
      status { 'queued' }
      queued_at { Time.current }
    end
    
    trait :sending do
      status { 'sending' }
    end
    
    trait :sent do
      status { 'sent' }
      sent_at { Time.current }
    end
    
    trait :delivered do
      status { 'delivered' }
    end
    
    trait :failed do
      status { 'failed' }
      failed_at { Time.current }
      failure_reason { 'Provider error' }
    end
  end
end
