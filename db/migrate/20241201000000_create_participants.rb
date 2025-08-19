class CreateParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :participants do |t|
      t.string :identifier, null: false
      t.timestamps
    end
    
    add_index :participants, :identifier, unique: true
  end
end
