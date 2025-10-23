# Alert Configuration Guide

This document describes how to configure alerting for the Rachel application.

## Overview

The application monitors critical metrics and can trigger alerts when thresholds are exceeded. Alerts are configured with two severity levels:

- **Critical**: Immediate attention required (e.g., high error rates, service degradation)
- **Warning**: Attention needed soon (e.g., approaching resource limits)

## Built-in Alert Thresholds

Current thresholds are defined in `lib/rachel/monitoring/alerts.ex`:

### HTTP Performance
- **Response Time**
  - Warning: 1000ms
  - Critical: 2000ms
- **Error Rate**
  - Warning: 2% (0.02)
  - Critical: 5% (0.05)

### System Resources
- **Memory Usage**
  - Warning: 768 MB
  - Critical: 1024 MB
- **CPU Usage**
  - Warning: 70%
  - Critical: 90%

### Game Health
- **Game Error Rate**
  - Warning: 5% (0.05)
  - Critical: 10% (0.10)
- **Active Games**
  - Warning: 800 concurrent games
  - Critical: 1000 concurrent games
- **Game Duration**
  - Warning: 96 minutes
  - Critical: 120 minutes

### Database Performance
- **Query Time**
  - Warning: 500ms
  - Critical: 1000ms
- **Connection Pool Usage**
  - Warning: 70% (0.70)
  - Critical: 90% (0.90)

## Notification Channels

### Development/Staging
By default, alerts are only logged in non-production environments.

### Production

Configure notification channels in `config/runtime.exs`:

```elixir
# Sentry for error tracking (already configured)
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

# Webhook for custom alerting (Slack, Discord, PagerDuty, etc.)
config :rachel, :alert_webhook_url, System.get_env("ALERT_WEBHOOK_URL")
```

## Webhook Integration

### Slack

1. Create a Slack Incoming Webhook: https://api.slack.com/messaging/webhooks
2. Set the `ALERT_WEBHOOK_URL` environment variable to your webhook URL
3. Alerts will be posted to your configured Slack channel

Example webhook payload:
```json
{
  "severity": "critical",
  "message": "Response time (2500ms) exceeds critical threshold (2000ms)",
  "metric": "response_time_ms",
  "value": 2500,
  "threshold": 2000,
  "metadata": {
    "route": "/api/games/123",
    "status": 200
  },
  "timestamp": "2025-01-15T14:30:00Z"
}
```

To format for Slack, your webhook endpoint should transform this into:
```json
{
  "text": ":rotating_light: CRITICAL ALERT",
  "attachments": [{
    "color": "danger",
    "fields": [
      {"title": "Message", "value": "Response time (2500ms) exceeds critical threshold (2000ms)"},
      {"title": "Metric", "value": "response_time_ms", "short": true},
      {"title": "Value", "value": "2500", "short": true}
    ]
  }]
}
```

### PagerDuty

1. Create a PagerDuty Events API v2 integration
2. Create a webhook endpoint that forwards alerts to PagerDuty
3. Set `ALERT_WEBHOOK_URL` to your webhook endpoint

Example PagerDuty event:
```json
{
  "routing_key": "YOUR_INTEGRATION_KEY",
  "event_action": "trigger",
  "payload": {
    "summary": "Response time (2500ms) exceeds critical threshold (2000ms)",
    "severity": "critical",
    "source": "rachel-web",
    "custom_details": {
      "metric": "response_time_ms",
      "value": 2500,
      "threshold": 2000
    }
  }
}
```

### Discord

1. Create a Discord webhook in your server settings
2. Set `ALERT_WEBHOOK_URL` to the Discord webhook URL
3. Transform the alert payload into Discord's format

Example Discord webhook:
```json
{
  "embeds": [{
    "title": ":rotating_light: Critical Alert",
    "description": "Response time (2500ms) exceeds critical threshold (2000ms)",
    "color": 15158332,
    "fields": [
      {"name": "Metric", "value": "response_time_ms", "inline": true},
      {"name": "Value", "value": "2500ms", "inline": true},
      {"name": "Threshold", "value": "2000ms", "inline": true}
    ],
    "timestamp": "2025-01-15T14:30:00Z"
  }]
}
```

## Custom Thresholds

To adjust thresholds for your deployment:

1. Edit `lib/rachel/monitoring/alerts.ex`
2. Modify the module attributes at the top of the file:
   ```elixir
   @response_time_critical_ms 2000  # Change to your desired value
   @response_time_warning_ms 1000
   ```
3. Recompile and deploy

For environment-specific thresholds, you can use application configuration:
```elixir
# In config/runtime.exs
config :rachel, Rachel.Monitoring.Alerts,
  response_time_critical_ms: System.get_env("ALERT_RESPONSE_TIME_CRITICAL", "2000") |> String.to_integer()
```

## Testing Alerts

To test your alerting setup in development:

```elixir
# In IEx
iex> alias Rachel.Monitoring.Alerts

# Check a threshold
iex> Alerts.check_threshold(:response_time_ms, 2500)
{:alert, %{severity: :critical, message: "...", ...}}

# Trigger a test alert
iex> {:alert, alert} = Alerts.check_threshold(:response_time_ms, 2500)
iex> Alerts.handle_alert({:alert, alert}, notify: [:log, :webhook])
```

## Monitoring Dashboard

View real-time metrics in Phoenix LiveDashboard:
- Development: http://localhost:4000/dev/dashboard
- Production: https://your-domain.com/dev/dashboard (requires authentication)

## Alert Fatigue Prevention

To avoid alert fatigue:

1. **Use appropriate severity levels**: Only mark genuinely critical issues as critical
2. **Set realistic thresholds**: Base thresholds on actual production metrics
3. **Aggregate warnings**: Group similar warnings into periodic digests
4. **Add context**: Include relevant metadata in alerts to enable quick diagnosis
5. **Monitor alert volume**: If you're getting too many alerts, adjust thresholds

## Troubleshooting

### Alerts not being sent

1. Check logs for telemetry handler attachment:
   ```bash
   grep "telemetry" log/production.log
   ```

2. Verify webhook URL is configured:
   ```elixir
   iex> Application.get_env(:rachel, :alert_webhook_url)
   ```

3. Test webhook manually:
   ```bash
   curl -X POST $ALERT_WEBHOOK_URL \
     -H "Content-Type: application/json" \
     -d '{"test": "alert"}'
   ```

### Too many alerts

1. Review recent alerts to identify patterns
2. Adjust thresholds in `lib/rachel/monitoring/alerts.ex`
3. Consider implementing alert rate limiting
4. Add alert aggregation for high-frequency events

## Future Enhancements

Potential improvements to the alerting system:

- [ ] Time-windowed error rate calculation (instead of per-event)
- [ ] Alert rate limiting to prevent notification storms
- [ ] Alert acknowledgment and silencing
- [ ] Historical alert dashboard
- [ ] Anomaly detection for unusual patterns
- [ ] Integration with incident management systems (Jira, Linear)
- [ ] Scheduled maintenance windows (disable alerts during deploys)
