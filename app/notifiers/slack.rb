module Notifiers
end

class Notifiers::Slack < Notifiers::Base
    def self.deliver(notification, config, state)
      client = build_client(config)

      blocks = if notification.resolution?
        build_resolved_blocks(notification, state)
      else
        build_blocks(notification)
      end

      client.chat_postMessage(
        channel: config["channel"],
        attachments: [
          {
            color: notification_color(notification),
            blocks: blocks,
            fallback: "#{notification.icon} #{notification.title}"
          }
        ]
      )

      if notification.resolution?
        clear_tracking(state)
      else
        track_delivery(state, notification)
      end
    end

    private

    def self.build_client(config)
      ::Slack::Web::Client.new(token: config["token"])
    end

    def self.build_blocks(notification)
      details = notification.details

      blocks = [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "#{notification.icon} #{notification.title}",
            emoji: true
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Project:* #{details[:project]}   *Environment:* #{details[:environment]}"
          }
        }
      ]

      if details[:changes].present?
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Summary:* #{details[:changes]}"
          }
        }
      end

      blocks << {
        type: "actions",
        elements: [
          {
            type: "button",
            text: {
              type: "plain_text",
              text: "View in DriftHound"
            },
            url: build_full_url(details[:url])
          }
        ]
      }

      blocks
    end

    def self.build_resolved_blocks(notification, state)
      details = notification.details
      resolved_at = Time.current.strftime("%Y-%m-%d %H:%M UTC")

      sent_at = state.metadata["sent_at"]
      duration_text = if sent_at
        duration = Time.current - Time.parse(sent_at)
        hours = (duration / 3600).to_i
        minutes = ((duration % 3600) / 60).to_i
        "#{hours}h #{minutes}m"
      else
        "unknown"
      end

      [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "#{notification.icon} #{notification.title}",
            emoji: true
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Project:* #{details[:project]}   *Environment:* #{details[:environment]}"
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Resolved:* #{resolved_at} (after #{duration_text})"
          }
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: "View in DriftHound"
              },
              url: build_full_url(details[:url])
            }
          ]
        }
      ]
    end

    def self.build_full_url(path)
      base_url = ENV.fetch("APP_URL", "http://localhost:3000")
      "#{base_url}#{path}"
    end

    def self.notification_color(notification)
      case notification.event_type
      when :drift_detected then "#FFA500"  # Orange/Yellow for drift
      when :error_detected then "#FF0000"  # Red for errors
      else "#36A64F"  # Green for resolved states
      end
    end
end
