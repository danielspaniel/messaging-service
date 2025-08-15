# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create some sample conversations and messages for testing
puts "Creating sample data..."

# Sample conversation 1: SMS conversation
conversation1 = Conversation.find_or_create_for_participants('+12016661234', '+18045551234')
Message.create!(
  conversation: conversation1,
  from: '+12016661234',
  to: '+18045551234',
  message_type: 'sms',
  body: 'Hello! This is a sample SMS message.',
  attachments: [],
  timestamp: 1.hour.ago,
  direction: 'outbound',
  messaging_provider_id: 'sample_msg_1'
)

Message.create!(
  conversation: conversation1,
  from: '+18045551234',
  to: '+12016661234',
  message_type: 'sms',
  body: 'Hi there! Thanks for your message.',
  attachments: [],
  timestamp: 30.minutes.ago,
  direction: 'inbound',
  messaging_provider_id: 'sample_msg_2'
)

# Sample conversation 2: Email conversation
conversation2 = Conversation.find_or_create_for_participants('user@usehatchapp.com', 'contact@gmail.com')
Message.create!(
  conversation: conversation2,
  from: 'user@usehatchapp.com',
  to: 'contact@gmail.com',
  message_type: 'email',
  body: '<html><body>Hello! This is a sample <b>HTML</b> email.</body></html>',
  attachments: ['https://example.com/document.pdf'],
  timestamp: 2.hours.ago,
  direction: 'outbound',
  xillio_id: 'sample_email_1'
)

Message.create!(
  conversation: conversation2,
  from: 'contact@gmail.com',
  to: 'user@usehatchapp.com',
  message_type: 'email',
  body: 'Thank you for your email! I received your document.',
  attachments: [],
  timestamp: 1.hour.ago,
  direction: 'inbound',
  xillio_id: 'sample_email_2'
)

puts "Sample data created successfully!"
puts "Conversations: #{Conversation.count}"
puts "Messages: #{Message.count}"