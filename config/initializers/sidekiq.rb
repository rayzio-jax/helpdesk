require "sidekiq"
require "sidekiq-scheduler"

Sidekiq.configure_server do |config|
  config.redis = { url: "redis://localhost:6379/0" }

  config.on(:startup) do
    schedule_file = File.join(Rails.root, "config/sidekiq.yml")

    if File.exist?(schedule_file)
      raw_config = YAML.load_file(schedule_file)

      # New location for schedule
      schedule = raw_config.dig(:scheduler, :schedule)

      if schedule
        Sidekiq.schedule = schedule
        Sidekiq::Scheduler.reload_schedule!
      else
        Rails.logger.warn "No Sidekiq schedule found in #{schedule_file}"
      end
    end

    # Kick off one poll job immediately on boot
    GmailPollJob.perform_now
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://localhost:6379/0" }
end
