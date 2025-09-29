class AddWatchToggleToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :gmail_watch_enabled, :boolean, default: false
  end
end
