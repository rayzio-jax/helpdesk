class AddMessageIdToTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :tickets, :message_id, :string
  end
end
