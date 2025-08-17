class AddStatusAndTimestampsToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :status, :string, default: 'pending', null: false
    add_column :messages, :queued_at, :datetime
    add_column :messages, :sent_at, :datetime
    add_column :messages, :failed_at, :datetime
    add_column :messages, :retry_count, :integer, default: 0
    add_column :messages, :error_message, :text
    
    add_index :messages, :status
    add_index :messages, [:status, :created_at]
  end
end
