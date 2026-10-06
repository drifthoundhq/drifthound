# API Usage

DriftHound provides a RESTful API for submitting Terraform drift check results.

## Authentication

All API requests require authentication using a Bearer token in the `Authorization` header:

```bash
Authorization: Bearer YOUR_API_TOKEN
```

See [API Token Management](#api-token-management) for details on generating tokens.

## Endpoints

### Submit a Drift Check

Submit the results of a Terraform drift check for a specific project and environment.

**Endpoint:** `POST /api/v1/projects/:project_key/environments/:environment_key/checks`

**Example Request:**

```bash
curl -X POST \
  http://localhost:3000/api/v1/projects/my-project/environments/my-env/checks \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "drift",
    "add_count": 2,
    "change_count": 1,
    "destroy_count": 0,
    "duration": 8.2,
    "raw_output": "Plan: 2 to add, 1 to change, 0 to destroy.",
    "directory": "infra/terraform/production",
    "repository": "https://github.com/myorg/infrastructure",
    "branch": "master"
  }'
```

### Request Parameters

#### URL Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `project_key` | string | Yes | Unique identifier for the project (alphanumeric, dashes, underscores) |
| `environment_key` | string | Yes | Unique identifier for the environment (alphanumeric, dashes, underscores) |

#### Body Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `status` | string | Yes | One of: `ok`, `drift`, `error`, `unknown` |
| `add_count` | integer | No | Number of resources to add |
| `change_count` | integer | No | Number of resources to change |
| `destroy_count` | integer | No | Number of resources to destroy |
| `duration` | float | No | Execution duration in seconds |
| `raw_output` | text | No | Full Terraform plan output |
| `environment_name` | string | No | Display name for the environment. Defaults to the titleized `environment_key` when the environment is created. When provided, it is applied on every call, so it also renames an existing environment. When omitted, the current name is kept. Must be a string; surrounding whitespace is removed. At most 255 characters; a longer or non-string value is rejected with `422 Unprocessable Entity` and nothing is created or renamed. The last name sent wins, so if several pipelines report the same environment, send the same name from all of them. |
| `directory` | string | No | Directory where Terraform is executed. Only set on first call; subsequent calls won't overwrite. Update via GUI. |
| `repository` | string | No | Repository URL (e.g., `https://github.com/org/repo`). Only set on first call; subsequent calls won't overwrite. Update via GUI. |
| `branch` | string | No | Repository branch (default: `main`). Only set on first call if different from default; update via GUI. |
| `notification_channel` | object | No | Optional notification channel configuration (see [Advanced Features](#advanced-features)) |

### Response

**Success Response (201 Created):**

```json
{
  "id": 123,
  "project_key": "my-project",
  "environment_key": "my-env",
  "status": "drift",
  "created_at": "2025-11-27T10:30:00Z"
}
```

**Error Responses:**

- `401 Unauthorized` - Missing or invalid API token
- `422 Unprocessable Entity` - Invalid status value or validation error

### Status Values

| Status | Description |
|--------|-------------|
| `ok` | No drift detected - infrastructure matches state |
| `drift` | Drift detected - changes pending |
| `error` | Error running drift check |
| `unknown` | Initial state or unable to determine |

### List Drift Check History

Read past drift checks, for example to chart drift trends in an external dashboard. Results are ordered newest first.

**Endpoints:**

- `GET /api/v1/projects/:project_key/environments/:environment_key/checks` - checks for one environment
- `GET /api/v1/checks` - checks across all projects

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `since` | ISO 8601 date or timestamp | No | Only checks created at or after this time (a date or a timestamp without an offset is read as UTC) |
| `until` | ISO 8601 date or timestamp | No | Only checks created before this time (a date or a timestamp without an offset is read as UTC) |
| `limit` | integer | No | Page size, 1 to 500 (default: 50) |
| `cursor` | string | No | The `next_cursor` value from the previous page |
| `project` | string | No | `GET /api/v1/checks` only: filter by project key |
| `environment` | string | No | `GET /api/v1/checks` only: filter by environment key |

**Example Request:**

```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
  "http://localhost:3000/api/v1/projects/my-project/environments/my-env/checks?since=2025-11-01&limit=100"
```

**Response (200 OK):**

```json
{
  "checks": [
    {
      "id": 123,
      "project_key": "my-project",
      "environment_key": "my-env",
      "status": "drift",
      "add_count": 2,
      "change_count": 1,
      "destroy_count": 0,
      "duration": 8,
      "execution_number": 42,
      "created_at": "2025-11-27T10:30:00Z",
      "change_summary": "2 to add, 1 to change"
    }
  ],
  "pagination": {
    "limit": 100,
    "has_more": true,
    "next_cursor": "MjAyNS0xMS0yN1QxMDozMDowMC4wMDAwMDBaLDEyMw"
  }
}
```

To fetch the next page, repeat the request with the same filters and `cursor` set to `next_cursor`. When `has_more` is `false`, `next_cursor` is `null`. The cursor points at a position in the list, so checks submitted while you page through do not cause duplicates or gaps.

History responses do not include `raw_output`. Use `GET /api/v1/projects/:project_key/environments/:key/drift` to read the full plan output of the latest check.

**Error Responses:**

- `400 Bad Request` - Invalid `since`, `until`, `limit` or `cursor`, or a `project` or `environment` that is not a single key
- `401 Unauthorized` - Missing or invalid API token
- `404 Not Found` - Unknown project or environment

### Update an Environment

Exclude an environment from the dashboard charts and stability score, or include it again. Needs a `write` token.

**Note:** any `write` token can set this flag through the API. The web UI only lets admins change it, so it is not admin-only over the API. Write tokens can already change the charts by submitting checks.

**Endpoint:** `PATCH /api/v1/projects/:project_key/environments/:key`

```bash
curl -X PATCH \
  http://localhost:3000/api/v1/projects/my-project/environments/staging \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"exclude_from_metrics": true}'
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `exclude_from_metrics` | boolean | Yes | `true` leaves the environment out of the dashboard charts and stability score; `false` includes it again. It stays in every list either way. |

The response is the environment, as returned by `GET /api/v1/projects/:project_key/environments/:key`. Environment objects in the read API include `exclude_from_metrics`.

**Error Responses:**

- `401 Unauthorized` - Missing or invalid API token
- `403 Forbidden` - The token is read-only
- `404 Not Found` - Unknown project or environment
- `422 Unprocessable Entity` - `exclude_from_metrics` is missing or not a boolean

## Advanced Features

### Notification Channel Configuration

You can optionally configure Slack notification channels per environment via the API:

```bash
curl -X POST \
  http://localhost:3000/api/v1/projects/my-project/environments/production/checks \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "drift",
    "add_count": 2,
    "change_count": 1,
    "destroy_count": 0,
    "notification_channel": {
      "channel_type": "slack",
      "enabled": true,
      "config": {
        "channel": "#custom-alerts"
      }
    }
  }'
```

**Notification Channel Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `channel_type` | string | Yes | Currently only `"slack"` is supported |
| `enabled` | boolean | No | Enable or disable notifications for this environment |
| `config.channel` | string | No | Slack channel name (e.g., `"#alerts"`). Falls back to global default if not provided |

**Notes:**
- The Slack token is always taken from the global configuration (`SLACK_BOT_TOKEN` or `config/notifications.yml`)
- This allows you to override the notification channel per environment without exposing tokens in API requests
- See [Slack Notifications documentation](slack-notifications.md) for more details on notification setup

## API Token Management

DriftHound provides a web-based interface for managing API tokens. Only admin users can create and manage tokens.

### Using the Web UI (Recommended)

1. Log in as an admin user
2. Click **API Tokens** in the navigation bar
3. Enter a name for your token (e.g., "CI/CD Pipeline"), choose its access level, and click **Create Token**
4. **Important:** Copy the token immediately - it will only be shown once!

The API Tokens page also displays:
- A list of all existing tokens with partial token previews
- The access level of each token
- Creation dates for each token
- Delete buttons to revoke tokens
- Usage examples showing how to authenticate API requests

### Token Access Levels

Each token has an access level:

| Access | Allowed requests | Use for |
|--------|------------------|---------|
| `write` (default) | All API endpoints, including submitting drift checks | CI/CD pipelines and the CLI |
| `read_plans` | `GET` and `HEAD` requests only, including plan output | Tools that need to show or analyse plans |
| `read` | `GET` and `HEAD` requests only, without plan output | Dashboards and reporting tools that only read drift status |

A `read` or `read_plans` token that sends any other request (for example `POST .../checks`) receives `403 Forbidden`:

```json
{ "error": "Forbidden: this API token is read-only" }
```

Plan output can contain sensitive values, so only `read_plans` and `write` tokens receive it. For a `read` token, `GET .../environments/:key/drift` still returns the check summary, without `raw_output` and with `"raw_output_restricted": true`.

Tokens created before access levels were introduced keep `write` access.

### Using the Rake Tasks

```bash
bin/rails "api_tokens:generate[CI Pipeline]"
bin/rails "api_tokens:generate[Reporting Dashboard,read]"
bin/rails "api_tokens:generate[Plan Viewer,read_plans]"
bin/rails api_tokens:list
bin/rails "api_tokens:revoke[42]"
```

### Token Security

- Tokens are only displayed once at creation time
- Store tokens securely (e.g., in CI/CD secrets, environment variables)
- Use descriptive names to identify token purposes
- Give tools that only read data a `read` token
- Revoke tokens that are no longer needed

## Health Check Endpoint

DriftHound provides a health check endpoint for load balancers and monitoring systems:

**Endpoint:** `GET /up`

**Response:**
- `200 OK` - Application is healthy
- `500 Internal Server Error` - Application failed to boot

**Note:** Health check requests are not logged in production to prevent log clutter.

## Best Practices

1. **Use descriptive project and environment keys** - Use kebab-case names like `infrastructure-prod` rather than cryptic codes
2. **Always include raw_output** - Helps with debugging and provides detailed context in the dashboard
3. **Set appropriate durations** - Helps track performance over time
4. **Use environment variables for tokens** - Never hardcode tokens in scripts
5. **Configure notifications per environment** - Use different Slack channels for production vs. staging alerts

## Example Integration

### GitHub Actions

```yaml
- name: Check Terraform Drift
  run: |
    drifthound --tool=terraform \
      --project=my-infrastructure \
      --environment=production \
      --token=${{ secrets.DRIFTHOUND_TOKEN }} \
      --api-url=${{ secrets.DRIFTHOUND_URL }} \
      --dir=./terraform
```

### GitLab CI

```yaml
drift_check:
  script:
    - drifthound --tool=terraform
        --project=my-infrastructure
        --environment=production
        --token=$DRIFTHOUND_TOKEN
        --api-url=$DRIFTHOUND_URL
        --dir=./terraform
```

## See Also

- [CLI Usage Guide](cli-usage.md) - For automated drift checking in CI/CD
- [Slack Notifications](slack-notifications.md) - Configure Slack alerts
