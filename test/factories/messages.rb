FactoryBot.define do
  factory :message do
    association :conversation
    from { '+12016661234' }
    to { '+18045551234' }
    message_type { 'sms' }
    body { 'This is a test message' }
    attachments { [] }
    timestamp { Time.current }
    direction { 'outbound' }
    messaging_provider_id { "msg_#{SecureRandom.hex(8)}" }
    
    trait :inbound do
      direction { 'inbound' }
      from { '+18045551234' }
      to { '+12016661234' }
    end
    
    trait :mms do
      message_type { 'mms' }
      attachments { ['https://example.com/image.jpg'] }
    end
    
    trait :email do
      message_type { 'email' }
      from { 'user@usehatchapp.com' }
      to { 'contact@gmail.com' }
      body { '<html><body>This is an <b>HTML</b> email</body></html>' }
      messaging_provider_id { nil }
      xillio_id { "email_#{SecureRandom.hex(8)}" }
    end
    
    trait :with_attachments do
      attachments { ['https://example.com/file1.pdf', 'https://example.com/file2.jpg'] }
    end
  end
end
