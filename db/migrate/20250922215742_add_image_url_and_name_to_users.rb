class AddImageUrlAndNameToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :image_url, :string
    add_column :users, :name, :string
  end
end
