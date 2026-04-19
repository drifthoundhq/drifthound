# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Seed data for testing Slack notifications (6 scenarios)"
    task notifications: :environment do
      puts "=" * 80
      puts "DriftHound Notification Testing Seeds"
      puts "=" * 80
      puts ""

      # Check if Slack is configured
      slack_enabled = Rails.configuration.notifications.dig(:slack, :enabled)
      slack_token = Rails.configuration.notifications.dig(:slack, :token)
      slack_default_channel = Rails.configuration.notifications.dig(:slack, :default_channel)
      slack_configured = slack_enabled && slack_token.present?

      # Define different channels for each scenario (for testing purposes)
      slack_channels = {
        payments: ENV.fetch("SLACK_CHANNEL_PAYMENTS", "#payments-drift"),
        auth: ENV.fetch("SLACK_CHANNEL_AUTH", "#auth-drift"),
        frontend: ENV.fetch("SLACK_CHANNEL_FRONTEND", "#frontend-drift"),
        api: ENV.fetch("SLACK_CHANNEL_API", "#api-drift"),
        database: ENV.fetch("SLACK_CHANNEL_DATABASE", "#database-drift")
      }

      puts "Slack Configuration:"
      puts "  - Enabled: #{slack_enabled ? '✓ Yes' : '✗ No'}"
      puts "  - Token: #{slack_token.present? ? '✓ Configured' : '✗ Missing'}"
      puts "  - Default Channel: #{slack_default_channel}"
      puts "  - Status: #{slack_configured ? '✓ Ready to send notifications' : '✗ Set SLACK_NOTIFICATIONS_ENABLED=true and SLACK_BOT_TOKEN'}"
      puts ""
      puts "Channels per project:"
      slack_channels.each do |project, channel|
        puts "  - #{project}: #{channel}"
      end
      puts ""

      # Force inline job processing so notifications are sent synchronously during seeding
      ActiveJob::Base.queue_adapter = :inline

      puts "Creating test scenarios..."
      puts ""

      # Scenario 1: Drift Detection
      project1 = Project.find_or_create_by!(key: "payment-service") do |p|
        p.name = "payment-service"
        p.repository = "https://github.com/acme/payment-service"
      end
      project1.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
        config: { "channel" => slack_channels[:payments] },
        enabled: true
      )

      env1 = project1.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.directory = "terraform/production"
      end
      env1.update!(last_checked_at: 1.hour.ago)

      # Create drift check showing drift
      env1.drift_checks.find_or_create_by!(execution_number: 1) do |c|
        c.status = :ok
        c.add_count = 0
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 45
        c.raw_output = "No changes. Infrastructure matches code."
        c.created_at = 2.hours.ago
      end

      puts "Scenario 1: Drift Detection (ok → drift)"
      puts "  Project: payment-service"
      puts "  Environment: Production"
      puts "  Expected: 🟡 Drift Detected notification"
      env1.update!(status: :ok)
      env1.update!(status: :drift)

      max_exec = env1.drift_checks.maximum(:execution_number) || 0
      env1.drift_checks.create!(
        status: :drift,
        add_count: 2,
        change_count: 1,
        destroy_count: 0,
        duration: 52,
        raw_output: "Terraform detected drift:\n  + resource 'db_instance' will be created\n  + resource 'cache_cluster' will be created\n  ~ resource 'app_server' will be updated",
        created_at: Time.current,
        execution_number: max_exec + 1
      )
      puts "  ✓ Status changed from 'ok' to 'drift'"
      puts ""

      # Scenario 1b: Same project, different environment with its own Slack channel
      env1b = project1.environments.find_or_create_by!(key: "staging") do |e|
        e.name = "Staging"
        e.directory = "terraform/staging"
      end
      env1b.update!(last_checked_at: 30.minutes.ago)

      # Override the project-level Slack channel for this specific environment
      env1b.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
        config: { "channel" => ENV.fetch("SLACK_CHANNEL_PAYMENTS_STAGING", "#payments-staging") },
        enabled: true
      )

      max_exec = env1b.drift_checks.maximum(:execution_number) || 0
      env1b.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :ok
        c.add_count = 0
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 38
        c.raw_output = "No changes. Infrastructure matches code."
        c.created_at = Time.current
      end

      puts "Scenario 1b: Environment-specific Slack channel"
      puts "  Project: payment-service"
      puts "  Environment: Staging"
      puts "  Project default channel: #{slack_channels[:payments]}"
      puts "  Environment override: #{ENV.fetch('SLACK_CHANNEL_PAYMENTS_STAGING', '#payments-staging')}"
      puts "  ✓ Staging uses its own Slack channel (overrides project default)"
      puts ""

      # Scenario 2: Error Detection
      project2 = Project.find_or_create_by!(key: "auth-service") do |p|
        p.name = "auth-service"
        p.repository = "https://gitlab.com/acme/auth-service"
      end
      project2.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
        config: { "channel" => slack_channels[:auth] },
        enabled: true
      )

      env2 = project2.environments.find_or_create_by!(key: "staging") do |e|
        e.name = "Staging"
        e.directory = "infra/staging"
      end
      env2.update!(last_checked_at: 30.minutes.ago)

      puts "Scenario 2: Error Detection (ok → error)"
      puts "  Project: auth-service"
      puts "  Environment: Staging"
      puts "  Expected: 🔴 Error Detected notification"
      env2.update!(status: :ok)
      env2.update!(status: :error)

      max_exec = env2.drift_checks.maximum(:execution_number) || 0
      env2.drift_checks.create!(
        status: :error,
        add_count: 0,
        change_count: 0,
        destroy_count: 0,
        duration: 15,
        raw_output: "Error: Failed to refresh state\nError: Could not connect to AWS API\nStatus code: 403",
        created_at: Time.current,
        execution_number: max_exec + 1
      )
      puts "  ✓ Status changed from 'ok' to 'error'"
      puts ""

      # Scenario 3: Drift Resolved
      project3 = Project.find_or_create_by!(key: "frontend-app") do |p|
        p.name = "frontend-app"
        p.repository = "https://github.com/acme/frontend-app"
      end
      project3.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
        config: { "channel" => slack_channels[:frontend] },
        enabled: true
      )

      env3 = project3.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.directory = "terraform/prod"
      end
      env3.update!(last_checked_at: 2.hours.ago)

      # First create drift
      env3.update!(status: :ok)
      env3.update!(status: :drift)

      max_exec = env3.drift_checks.maximum(:execution_number) || 0
      env3.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :drift
        c.add_count = 1
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 38
        c.raw_output = "Drift detected in CDN configuration"
        c.created_at = 1.hour.ago
      end

      puts "Scenario 3: Drift Resolved (drift → ok)"
      puts "  Project: frontend-app"
      puts "  Environment: Production"
      puts "  Expected: 🟢 Drift Resolved notification"
      sleep(0.5) # Small delay to ensure different timestamps
      env3.update!(status: :ok)

      max_exec = env3.drift_checks.maximum(:execution_number) || 0
      env3.drift_checks.create!(
        status: :ok,
        add_count: 0,
        change_count: 0,
        destroy_count: 0,
        duration: 42,
        raw_output: "Infrastructure now matches code. Drift resolved.",
        created_at: Time.current,
        execution_number: max_exec + 1
      )
      puts "  ✓ Status changed from 'drift' to 'ok'"
      puts ""

      # Scenario 4: Error Resolved
      project4 = Project.find_or_create_by!(key: "api-gateway") do |p|
        p.name = "api-gateway"
        p.repository = "https://github.com/acme/api-gateway"
      end
      project4.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
        config: { "channel" => slack_channels[:api] },
        enabled: true
      )

      env4 = project4.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.directory = "infrastructure/api"
      end
      env4.update!(last_checked_at: 45.minutes.ago)

      # First create error
      env4.update!(status: :ok)
      env4.update!(status: :error)

      max_exec = env4.drift_checks.maximum(:execution_number) || 0
      env4.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :error
        c.add_count = 0
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 8
        c.raw_output = "Terraform state locked by another process"
        c.created_at = 30.minutes.ago
      end

      puts "Scenario 4: Error Resolved (error → ok)"
      puts "  Project: api-gateway"
      puts "  Environment: Production"
      puts "  Expected: 🟢 Error Resolved notification"
      sleep(0.5)
      env4.update!(status: :ok)

      max_exec = env4.drift_checks.maximum(:execution_number) || 0
      env4.drift_checks.create!(
        status: :ok,
        add_count: 0,
        change_count: 0,
        destroy_count: 0,
        duration: 55,
        raw_output: "State lock released. Infrastructure check completed successfully.",
        created_at: Time.current,
        execution_number: max_exec + 1
      )
      puts "  ✓ Status changed from 'error' to 'ok'"
      puts ""

      # Scenario 5: No notification (lateral move - drift to drift)
      project5 = Project.find_or_create_by!(key: "database-service") do |p|
        p.name = "database-service"
      end
      project5.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
        config: { "channel" => slack_channels[:database] },
        enabled: true
      )

      env5 = project5.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.status = :drift
        e.directory = "terraform/database"
      end
      env5.update!(last_checked_at: 20.minutes.ago)

      puts "Scenario 5: No Notification (drift → drift - lateral move)"
      puts "  Project: database-service"
      puts "  Environment: Production"
      puts "  Expected: ✗ No notification (spam prevention)"
      env5.update!(status: :drift) # Same status, should not notify

      max_exec = env5.drift_checks.maximum(:execution_number) || 0
      env5.drift_checks.create!(
        status: :drift,
        add_count: 1,
        change_count: 2,
        destroy_count: 0,
        duration: 61,
        raw_output: "Still drifting with additional changes",
        created_at: Time.current,
        execution_number: max_exec + 1
      )
      puts "  ✓ Status unchanged 'drift' → 'drift' (blocked by lateral_move check)"
      puts ""

      # Scenario 6: Environment without notification channel
      project6 = Project.find_or_create_by!(key: "no-notifications") do |p|
        p.name = "no-notifications"
      end
      # Intentionally NOT creating notification channel

      env6 = project6.environments.find_or_create_by!(key: "development") do |e|
        e.name = "Development"
      end
      env6.update!(last_checked_at: 10.minutes.ago)

      puts "Scenario 6: No Notification Channel Configured"
      puts "  Project: no-notifications"
      puts "  Environment: Development"
      puts "  Expected: ✗ No notification (no channels configured)"
      env6.update!(status: :ok)
      env6.update!(status: :drift)
      puts "  ✓ Status changed 'ok' → 'drift' but no channels configured"
      puts ""

      # Summary
      puts "=" * 80
      puts "Notification Scenarios Summary"
      puts "=" * 80
      puts ""
      puts "Expected Notifications: 6"
      puts "  - Scenario 1: Drift Detected (payment-service)"
      puts "  - Scenario 2: Error Detected (auth-service)"
      puts "  - Scenario 3a: Drift Detected (frontend-app)"
      puts "  - Scenario 3b: Drift Resolved (frontend-app)"
      puts "  - Scenario 4a: Error Detected (api-gateway)"
      puts "  - Scenario 4b: Error Resolved (api-gateway)"
      puts ""
      puts "Blocked Notifications: 2"
      puts "  - Scenario 5: Lateral move (drift→drift)"
      puts "  - Scenario 6: No notification channel"
      puts ""

      if slack_configured
        puts "✓ Check the following Slack channels for notifications:"
        puts ""
        puts "  #{slack_channels[:payments]} → payment-service/production (Project default)"
        puts "  #{ENV.fetch('SLACK_CHANNEL_PAYMENTS_STAGING', '#payments-staging')} → payment-service/staging (Environment override)"
        puts "  #{slack_channels[:auth]} → auth-service (Error Detected)"
        puts "  #{slack_channels[:frontend]} → frontend-app (Drift Detected + Resolved)"
        puts "  #{slack_channels[:api]} → api-gateway (Error Detected + Resolved)"
        puts "  #{slack_channels[:database]} → database-service (No notification - lateral move)"
        puts ""
        puts "Channel inheritance example (payment-service):"
        puts "  - Production env → uses project default: #{slack_channels[:payments]}"
        puts "  - Staging env → uses environment override: #{ENV.fetch('SLACK_CHANNEL_PAYMENTS_STAGING', '#payments-staging')}"
        puts ""
        puts "Note: Jobs are processed with :inline adapter in development."
        puts "      Notifications should appear immediately."
        puts ""
        puts "Expected notification types:"
        puts "  - 2x Drift Detected (orange/yellow)"
        puts "  - 2x Error Detected (red)"
        puts "  - 1x Drift Resolved (green)"
        puts "  - 1x Error Resolved (green)"
      else
        puts "⚠ Slack is not configured. Set environment variables to test:"
        puts "  export SLACK_NOTIFICATIONS_ENABLED=true"
        puts "  export SLACK_BOT_TOKEN=xoxb-your-token-here"
        puts ""
        puts "Optionally set custom channels per project:"
        puts "  export SLACK_CHANNEL_PAYMENTS=#your-payments-channel"
        puts "  export SLACK_CHANNEL_AUTH=#your-auth-channel"
        puts "  export SLACK_CHANNEL_FRONTEND=#your-frontend-channel"
        puts "  export SLACK_CHANNEL_API=#your-api-channel"
        puts "  export SLACK_CHANNEL_DATABASE=#your-database-channel"
      end
      puts "=" * 80
    end
  end
end
