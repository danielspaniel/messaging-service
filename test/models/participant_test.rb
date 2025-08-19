require 'test_helper'

class ParticipantTest < ActiveSupport::TestCase
  def test_should_validate_presence_of_identifier
    participant = Participant.new
    assert_not participant.valid?
    assert_includes participant.errors[:identifier], "can't be blank"
  end
  
  def test_should_validate_uniqueness_of_identifier
    create(:participant, identifier: 'test@example.com')
    
    duplicate = Participant.new(identifier: 'test@example.com')
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:identifier], "has already been taken"
  end
  
  def test_find_or_create_by_identifier
    # Should create new participant
    participant = Participant.find_or_create_by_identifier('new@example.com')
    assert participant.persisted?
    assert_equal 'new@example.com', participant.identifier
    
    # Should find existing participant
    same_participant = Participant.find_or_create_by_identifier('new@example.com')
    assert_equal participant.id, same_participant.id
  end
  
  # Association tests are redundant - Rails handles this
end
