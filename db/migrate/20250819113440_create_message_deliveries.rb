class CreateMessageDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :message_deliveries do |t|
      t.references :message, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: { to_table: :participants }
      t.string :status, null: false, default: 'pending'
      t.string :provider_message_id
      t.datetime :sent_at
      t.datetime :failed_at
      t.text :failure_reason
      t.integer :retry_count, default: 0

      t.timestamps
    end
    
    add_index :message_deliveries, [:message_id, :status]
    add_index :message_deliveries, :provider_message_id
  end
end
