class GmailPollJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Running GmailPolJob"
    Session.active.includes(:user).find_each do |session|
      user = session.user
      next unless user&.accounts

      begin
        # Poll on init
        GmailService.new(user).poll(1.hour.ago)

        # Update last polled time
        last_polled_at = Time.current
        user.accounts.find_by(provider: "google_oauth2")&.update!(last_polled_at: last_polled_at)

        # Fetch tickets
        tickets = user.tickets.all.order(received_at: :desc)

        # Broadcast updated tickets
        Turbo::StreamsChannel.broadcast_replace_to(
          "ticket_list",
          target: "ticket_list",
          partial: "tickets/ticket",
          collection: @tickets,
          as: :ticket
        )

        # Broadcast flash message
        Turbo::StreamsChannel.broadcast_replace_to(
          "flash_messages",
          target: "flash_messages",
          partial: "tickets/flash",
          locals: { notice: "Polled emails successfully" }
        )

        # Broadcast next poll timestamp
        Turbo::StreamsChannel.broadcast_replace_to(
          "next_poll",
          target: "next_poll",
          partial: "tickets/next_poll",
          locals: { next_poll_time: last_polled_at + 1.minute }
        )
      rescue => e
        Rails.logger.error "GmailPollJob failed for user #{@user&.id}: #{e.message}"
      end
    end
  end
end
