class AddLastPolledAtToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :last_polled_at, :datetime
  end
end
