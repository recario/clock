# frozen_string_literal: true
require 'dotenv/load'
require 'sidekiq'
require 'active_support'
require 'active_support/core_ext/integer/time'
require 'active_support/core_ext/object/blank'

redis_url = "redis://#{ENV.fetch('REDIS_SERVICE_HOST', 'localhost')}:#{ENV.fetch('REDIS_SERVICE_PORT', 6379)}"

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

REDIS = Redis.new(url: redis_url)

module Clockwork
  ### SERVER ###

  if ENV['ENABLED_REFRESH_MV_EA'].present?
    every(ENV.fetch('INTERVAL_REFRESH_MV_EA_SEC', 1).to_i.seconds, 'Refresh Effective Ads Materialized View', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'EffectiveAdsRefreshMaterializedView',
        'args' => [],
        'queue' => 'refresh-matviews',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_REFRESH_DB_STATS'].present?
    every(ENV.fetch('INTERVAL_REFRESH_DB_STATS_SEC', 300).to_i.seconds, 'Update Dashboard Stats', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'DashboardStatsRefreshMaterializedView',
        'args' => [],
        'queue' => 'refresh-matviews',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_REFRESH_MV_BW'].present?
    every(ENV.fetch('INTERVAL_REFRESH_MV_BW_HOUR', 1).to_i.hour, 'Refresh Budget Widget Materialized View', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'BudgetWidgetRefreshMaterializedView',
        'args' => [],
        'queue' => 'refresh-matviews',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_REFRESH_MV_EUC'].present?
    every(ENV.fetch('INTERVAL_REFRESH_MV_EUC_SEC', 1).to_i.seconds, 'Refresh Effective UserContacts Materialized View', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'EffectiveUserContactsRefreshMaterializedView',
        'args' => [],
        'queue' => 'refresh-matviews',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_REQUEST_ACTUALIZE'].present?
    every(ENV.fetch('INTERVAL_REQUEST_ACTUALIZE_SEC', 60).to_i.seconds, 'Request Provider to Actualize Ads', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'ProviderActualizeRequest',
        'args' => [],
        'queue' => 'provider-actualize',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_MARK_DELETED_ADS'].present?
    every(ENV.fetch('INTERVAL_MARK_DELETED_ADS_DAY', 1).to_i.day, 'Mark old ads as deleted', at: '04:00', tz: 'UTC', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'MarkOldAdsAsDeleted',
        'args' => [],
        'queue' => 'default',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_DELETE_VREQ'].present?
    every(ENV.fetch('INTERVAL_DELETE_VREQ_HOUR', 1).to_i.hour, 'Delete Old VerificationRequests', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'DeleteOldVerificationRequests',
        'args' => [],
        'queue' => 'default',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_BACKUP'].present?
    every(ENV.fetch('INTERVAL_BACKUP_DAY', 1).to_i.day, 'Backup Database', at: '03:00', tz: 'UTC', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'BackupDatabase',
        'args' => [],
        'queue' => 'system',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_VACUUM'].present?
    every(ENV.fetch('INTERVAL_VACUUM_DAY', 1).to_i.day, 'Vacuum Postgresql', at: '05:00', tz: 'UTC', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'VacuumDatabase',
        'args' => [],
        'queue' => 'system',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_SNAPSHOT_UA'].present?
    every(ENV.fetch('INTERVAL_SNAPSHOT_UA_DAY', 1).to_i.day, 'User Activity Snapshot', at: '00:00', tz: 'UTC', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'SnapshotUserDevices',
        'args' => [],
        'queue' => 'analytics',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  ### PROVIDER ###

  if ENV['ENABLED_CRAWL'].present?
    every(ENV.fetch('INTERVAL_CRAWL_HOUR', 1).to_i.hour, 'Crawl auto.ria.com', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'AutoRia::CrawlerWorker',
        'args' => [],
        'queue' => 'provider-auto-ria-crawler',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_SCRAPE'].present?
    every(ENV.fetch('INTERVAL_SCRAPE_SEC', 10).to_i.second, 'Scrape auto.ria.com', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'AutoRia::Scraper',
        'args' => [],
        'queue' => 'provider-auto-ria-scraper',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_ACTUALIZE'].present?
    every(ENV.fetch('INTERVAL_ACTUALIZE_SEC', 2).to_i.seconds, 'Actualize auto.ria.com', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'AutoRia::Actualizer',
        'args' => [],
        'queue' => 'provider-auto-ria-actualizer',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_REFRESH_MV_BPN'].present?
    every(ENV.fetch('INTERVAL_REFRESH_MV_BPN_DAY', 1).to_i.days, 'Refresh Business Phone Numbers Materialized View', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'BusinessPhoneNumbersRefreshMaterializedView',
        'args' => [],
        'queue' => 'refresh-matviews',
        'retry' => true,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_SNAPSHOT_SYS'].present?
    every(ENV.fetch('INTERVAL_SNAPSHOT_SYS_DAYS', 1).to_i.days, 'Snapshot Dashboard Stats', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'SnapshotSystemStats',
        'args' => [],
        'queue' => 'default',
        'retry' => false,
        'backtrace' => false,
      )
    end
  end

  if ENV['ENABLED_SNAPSHOT_USER_VISIBILITY'].present?
    every(ENV.fetch('INTERVAL_SNAPSHOT_USER_VISIBILITY_HOURS', 24).to_i.hours, 'Snapshot User Visibility', skip_first_run: true) do
      Sidekiq::Client.push(
        'class' => 'SnapshotUserVisibility',
        'args' => [],
        'queue' => 'default',
        'retry' => false,
        'backtrace' => false,
      )
    end
  end
end
