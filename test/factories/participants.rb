FactoryBot.define do
  factory :participant do
    sequence(:identifier) { |n| "user#{n}" }
  end
end
