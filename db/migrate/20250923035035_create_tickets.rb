class CreateTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :tickets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :mail_id, null: false
      t.string :from_email, null: false
      t.string :subject, null:  false
      t.text :body
      t.datetime :received_at, null: false

      t.timestamps
    end
    add_index :tickets, :mail_id, unique: true
  end
end
