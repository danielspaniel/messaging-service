require "test_helper"

class MessageDeliveryTest < ActiveSupport::TestCase
  def test_belongs_to_message_and_recipient
    delivery = create(:message_delivery)
    assert_instance_of Message, delivery.message
    assert_instance_of Participant, delivery.recipient
  end
  
  def test_validates_status_inclusion
    delivery = build(:message_delivery, status: 'invalid')
    assert_not delivery.valid?
    assert_includes delivery.errors[:status], "is not included in the list"
  end
  
  def test_mark_as_sent_updates_message_status
    message = create(:message)
    delivery = create(:message_delivery, message: message, status: 'sending')
    
    delivery.mark_as_sent!('provider_123')
    
    assert_equal 'sent', delivery.reload.status
    assert_equal 'provider_123', delivery.provider_message_id
    assert_not_nil delivery.sent_at
  end
  
  def test_mark_as_failed_updates_message_status
    message = create(:message)
    delivery = create(:message_delivery, message: message, status: 'sending')
    
    delivery.mark_as_failed!('Provider timeout')
    
    assert_equal 'failed', delivery.reload.status
    assert_equal 'Provider timeout', delivery.failure_reason
    assert_not_nil delivery.failed_at
    assert_equal 1, delivery.retry_count
  end
end
