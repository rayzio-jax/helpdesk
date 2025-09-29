require "google/apis/gmail_v1"

class GmailService
  def initialize(user)
    @user = user
    @account = user.accounts.find_by(provider: "google_oauth2")
    @service = Google::Apis::GmailV1::GmailService.new
    @service.authorization = authorize
  end

  def authorize
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      scope: [ "https://www.googleapis.com/auth/gmail.modify" ],
      access_token: @account.access_token,
      refresh_token: @account.refresh_token,
      expires_at: @account.expires_at
    )

    credentials.refresh! if credentials.expired?
    @account.update!(
      access_token: credentials.access_token,
      expires_at: credentials.expires_at
    ) if credentials.access_token != @account.access_token || credentials.expires_at != @account.expires_at

    credentials
  end

  def send_reply(to, subject, body, in_reply_to)
    require "mail"

    from_address = @user.email_address
    to_address = to.presence || raise("Recipient address is required")

    mail = Mail.new do
      from from_address
      to to_address
      subject subject
      body body
    end
    mail["In-Reply-To"] = "<#{in_reply_to}>"
    mail["References"] = "<#{in_reply_to}>"

    Rails.logger.info "Mail: #{mail}"

    message = Google::Apis::GmailV1::Message.new(raw: mail.to_s)
    @service.send_user_message("me", message)
  end

  # Polling method
  def poll(after = nil)
    latest_ticket_time = Ticket.where(user: Current.user).maximum(:received_at)
    query_time = after || latest_ticket_time || Time.now
    query = "in:inbox is:unread after#{query_time.to_i}"

    messages = @service.list_user_messages("me", q: query, max_results: 10).messages || []
    messages.map do |msg|
      email = @service.get_user_message("me", msg.id, format: "full")
      payload = email.payload
      mail_id = email.id
      from = email.headers.find { |h| h.name == "From" }.value
      subject = email.headers.find { |h| h.name == "Subject" }.value
      body = payload.parts&.find { |p| p.mime_type == "text/plain" }&.body&.data || ""
      received_at = email.internal_date / 1000

      Current.user.tickets.create!(mail_id: mail_id, from_email: from, subject: subject, body: body, received_at: received_at)
      @service.modify_message("me", msg.id, Google::Apis::GmailV1::ModifyMessageRequest.new(remove_label_ids: [ "UNREAD" ]))
    end
  end

  # Pub/Sub method
  #
  def enable_watch
    response = @service.watch_user("me", Google::Apis::GmailV1::WatchRequest.new(topic_name: ENV["GOOGLE_PUBSUB_TOPIC"], label_ids: [ "INBOX" ], label_filter_behavior: "include"))
    @account.update!(gmail_watch_enabled: true, gmail_history_id: response.history_id)

    Rails.logger.info "✅ Gmail watch enabled for account #{@account.id}"
    Rails.logger.info "📬 Watch response: #{response.inspect}"
  rescue => e
    Rails.logger.error "❌ Failed to enable Gmail watch for account #{@account.id}: #{e.message}"
    raise
  end

  def disable_watch
    response = @service.stop_user("me")
    @account.update!(gmail_watch_enabled: false)

    Rails.logger.info "🛑 Gmail watch disabled for account #{@account.id}"
    Rails.logger.info "📭 Stop watch response: #{response.inspect}"
  rescue => e
    Rails.logger.error "❌ Failed to disable Gmail watch for account #{@account.id}: #{e.message}"
    raise
  end

  # Email processing into tickets

  def process_new_emails(history_id)
    start_id = @account.gmail_history_id || history_id
    history = @service.list_user_histories("me", start_history_id: start_id, label_id: "INBOX")
    return unless history.history&.any?

    history.history.each do |h|
      h.messages_added&.each do |msg|
        email = @service.get_user_message("me", msg.message.id)
        @service.modify_message("me", msg.message.id, Google::Apis::GmailV1::ModifyMessageRequest.new(remove_label_ids: [ "UNREAD" ]))
        create_ticket(email)
      end
    end
    @account.update(gmail_history_id: history_id)
  end

  def create_ticket(email)
    email_value = email.payload.headers.find { |h| h.name == "From" }&.value
    from_email = Mail::Address.new(email_value).address
    Ticket.create!(
      user: @user,
      mail_id: email.id,
      message_id: email.payload.headers.find { |h| h.name == "Message-ID" }&.value&.delete("<>"),
      from_email: from_email || "Unknown",
      subject: email.payload.headers.find { |h| h.name == "Subject" }&.value || "No Subject",
      body: email.snippet,
      received_at: Time.at(email.internal_date.to_i / 1000)
    )
  rescue ActiveRecord::RecordNotUnique
    # Skip duplicates
  end
end
