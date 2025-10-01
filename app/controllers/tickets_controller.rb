class TicketsController < ApplicationController
  allow_unauthenticated_access only: %i[ push ]

  before_action :set_service_and_account, except: [ :push ]
  skip_before_action :verify_authenticity_token, only: [ :push ]

  def index_with_poll
    @tickets = @user.tickets.all.order(received_at: :desc)

    if sidekiq_running?
      # Sidekiq is running → compute next poll normally
      last_run = @user.accounts.maximum(:last_polled_at) || Time.current
      @next_poll_time = last_run + 1.minute
    else
      # Sidekiq is down → show paused
      @next_poll_time = nil
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("ticket_list", partial: "tickets/ticket", collection: @tickets, as: :ticket),
          turbo_stream.replace("next_poll", partial: "tickets/next_poll", locals: { next_poll_time: @next_poll_time })
        ]
      end
      format.html
    end
  end

  def index_with_pubsub
    @tickets = @user.tickets.all.order(received_at: :desc)
    @watcher = @account.gmail_watch_enabled? ? "enabled" : "disabled"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("ticket_list", partial: "tickets/ticket", collection: @tickets, as: :ticket)
      end
      format.html
    end
  end

  def reply
    ticket = Ticket.find(params[:id])
    raise "Ticket not found" unless ticket
    raise "User not authenticated" unless @user

    @service.send_reply(params[:to], params[:subject], params[:body], ticket.message_id)
    flash[:notice] = "Reply sent."
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("flash_messages", partial: "flash")
      end
      format.html { redirect_to tickets_pubsub_path, notice: "Reply sent." }
    end

  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Ticket not found."
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("flash_messages", partial: "flash")
      end
      format.html { redirect_to tickets_pubsub_path, alert: "Ticket not found." }
    end

  rescue StandardError => e
    Rails.logger.error "Reply error: #{e.message}"
    flash[:alert] = "Failed to send reply."
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("flash_messages", partial: "flash")
      end
      format.html { redirect_to tickets_pubsub_path, alert: "Failed to send reply." }
    end
  end

  def toggle_gmail_watch
    begin
      if @account.gmail_watch_enabled?
        @service.disable_watch
        flash.now[:notice] = "🛑 Gmail watch disabled."
        @watcher = "disabled"
      else
        @service.enable_watch
        flash.now[:notice] = "✅ Gmail watch enabled."
        @watcher = "enabled"
      end
    rescue => e
      Rails.logger.error "Gmail watch toggle error: #{e.message}"
      flash.now[:alert] = "Failed to toggle Gmail watch. Please try again."
      @watcher = @account.gmail_watch_enabled? ? "enabled" : "disabled"
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("gmail_watch_status", partial: "tickets/watch_status", locals: { watcher: @watcher })
      end
      format.html { redirect_to tickets_pubsub_path }
    end
  end

  def push
    data = params.dig(:message, :data)

    if data.present?
      decoded = JSON.parse(Base64.urlsafe_decode64(data))
      email = decoded["emailAddress"]
      historyId = decoded["historyId"]

      user = User.find_by(email_address: email)
      if user
        service = GmailService.new(user)
        service.process_new_emails(historyId)
      else
        Rails.logger.warn "No account found for #{email}"
      end
    else
      Rails.logger.warn "Push received with no data"
    end

    head :ok
  end

  def poll
    @service.poll(1.hour.ago)
    flash.now[:notice] = "Polled emails successfully"

    @tickets = @user.tickets.all.order(received_at: :desc)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("flash_messages", partial: "flash"),
          turbo_stream.replace("ticket_list", partial: "tickets/ticket", collection: @tickets, as: :ticket)
        ]
      end
      format.html { redirect_to tickets_polling_path }
    end
  end

  private

  def set_service_and_account
    @user = Current.user
    unless @user
      Rails.logger.error "Current.user is nil in set_service_and_account"
      raise "User not authenticated"
    end
    @account = @user.accounts.find_by(provider: "google_oauth2")
    @service = GmailService.new(@user)
  end

  def sidekiq_running?
    Sidekiq::ProcessSet.new.size > 0
  end
end
