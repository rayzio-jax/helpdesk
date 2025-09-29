class AddGmailHistoryIdToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :gmail_history_id, :string
  end
end
