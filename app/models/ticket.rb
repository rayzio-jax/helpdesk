class Ticket < ApplicationRecord
  belongs_to :user

  after_create_commit  -> { broadcast_prepend_later_to "ticket_list" }
  after_update_commit  -> { broadcast_replace_later_to "ticket_list" }
  after_destroy_commit -> { broadcast_remove_to "ticket_list" }
end
