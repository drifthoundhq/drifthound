# Configuration Guide

DriftHound can be configured using environment variables for deployment flexibility. This guide covers all available configuration options.

## Application Settings

### APP_URL

The base URL where DriftHound is hosted. Used for generating links in Slack notifications.

**Required:** Recommended for production
**Default:** `http://localhost:3000`
**Example:** `https://drifthound.example.com`

```bash
APP_URL=https://drifthound.example.com
```

**Usage:**
- Generates clickable "View in DriftHound" buttons in Slack notifications
- Should match your actual domain (without trailing slash)

### RAILS_ENV

The Rails environment to run in.

**Required:** No
**Default:** `development`
**Options:** `development`, `test`, `production`

```bash
RAILS_ENV=production
```

### RAILS_LOG_LEVEL

Controls the verbosity of application logs.

**Required:** No
**Default:** `info`
**Options:** `debug`, `info`, `warn`, `error`, `fatal`

```bash
RAILS_LOG_LEVEL=info
```

**Recommendations:**
- `info` for production (default)
- `debug` for troubleshooting (includes SQL queries and detailed logs)
- `warn` or `error` for high-traffic deployments

### SECRET_KEY_BASE

Rails secret key used for encrypting sessions, cookies, and other sensitive data.

**Required:** Yes (production only)
**Format:** 128-character hexadecimal string (64 bytes)

```bash
SECRET_KEY_BASE=your-generated-secret-key-base
```

**How to generate:**

```bash
# Using OpenSSL (recommended)
openssl rand -hex 64

# Or using Rails (requires working bundle)
bin/rails secret
```

**Security Notes:**
- **Never commit this to version control**
- Use a secrets management system (e.g., sops, AWS Secrets Manager, HashiCorp Vault)
- Changing this value will invalidate all existing sessions and encrypted data
- Each environment should use a different secret

## Access Control

### PUBLIC_MODE

Controls whether DriftHound requires authentication for viewing content.

**Required:** No
**Default:** `false` (private - authentication required)
**Options:** `true`, `false`

```bash
# Private mode (default) - requires login to view anything
PUBLIC_MODE=false

# Public mode - anyone can view dashboard, projects, environments
PUBLIC_MODE=true
```

**Behavior:**

| Mode | Dashboard | Projects | Environments | Checks | Admin Actions |
|------|-----------|----------|--------------|--------|---------------|
| Private (`false`) | 🔒 Login required | 🔒 Login required | 🔒 Login required | 🔒 Login required | 🔒 Admin only |
| Public (`true`) | ✅ Public | ✅ Public | ✅ Public | ✅ Public | 🔒 Admin only |

**Notes:**
- **Private by default** - New deployments require authentication out of the box
- Admin actions (delete projects/environments, exclude environments from metrics, user management, API tokens) always require authentication regardless of this setting
- Use public mode for internal dashboards where authentication would add friction
- Use private mode for sensitive infrastructure data or external-facing deployments

**Use cases:**

- **Private mode (recommended)**: Production deployments, sensitive infrastructure data, compliance requirements
- **Public mode**: Internal team dashboards, demo instances, open-source project monitoring

### PLAN_OUTPUT_MIN_ROLE

Minimum role required to see the raw Terraform plan output on an environment page. Plan output can include resource attributes and values that you may not want every viewer to read.

**Required:** No
**Default:** `viewer` (everyone who can open the environment page sees plan output, the same as before this setting existed)
**Options:** `viewer`, `editor`, `admin`

```bash
# Only editors and admins can expand plan output in the web UI
PLAN_OUTPUT_MIN_ROLE=editor
```

**Behavior:**

| `PLAN_OUTPUT_MIN_ROLE` | Anonymous (public mode) | Viewer | Editor | Admin |
|------------------------|-------------------------|--------|--------|-------|
| `viewer` (default) | ✅ Plan output | ✅ Plan output | ✅ Plan output | ✅ Plan output |
| `editor` | 🔒 Restricted | 🔒 Restricted | ✅ Plan output | ✅ Plan output |
| `admin` | 🔒 Restricted | 🔒 Restricted | 🔒 Restricted | ✅ Plan output |

**Notes:**
- Users below the minimum role still see the environment's status, check history, change counts and durations; each check shows "Plan output restricted" in place of the Plan button, and the output is not sent to the browser.
- Anonymous visitors in public mode count as below `viewer`: they see plan output only when the minimum role is `viewer`.
- The value is case-insensitive. Any other value stops the application at boot with an error.
- This setting applies to the web UI only. The token-authenticated API endpoint `GET /api/v1/projects/:project_key/environments/:key/drift` still returns `raw_output` to API tokens with plan access (`write` tokens, and `read_plans` tokens once #143 merges).
- The role this setting compares against can come from any login method, including a GitHub team mapping, not only the built-in password roles. For example, with `PLAN_OUTPUT_MIN_ROLE=editor`, viewers see status and dashboards but not raw plan output.

## Admin Authentication

DriftHound includes a web-based admin authentication system to protect destructive operations like deleting projects and environments. Admin credentials are configured via environment variables.

### ADMIN_EMAIL

Email address for the admin user account.

**Required:** Yes (production only)
**Example:**

```bash
ADMIN_EMAIL=admin@example.com
```

### ADMIN_PASSWORD

Password for the admin user account.

**Required:** Yes (production only)
**Minimum:** 6 characters
**Example:**

```bash
ADMIN_PASSWORD=your-secure-password
```

### How Admin User Creation Works

**Development:**
- Run `rails db:seed` to create an admin user with defaults (`admin` / `changeme`)
- Or set `ADMIN_EMAIL` and `ADMIN_PASSWORD` before seeding for custom credentials

**Production:**
- Both `ADMIN_EMAIL` and `ADMIN_PASSWORD` environment variables are **required**
- The admin user is created automatically during `rails db:migrate`
- If credentials are not provided, both migration and app boot will fail with an error

```bash
# Production deployment
ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=secure_password rails db:migrate
```

### Security Notes

- **Never use default credentials in production** - The migration will fail if you don't provide credentials
- **Use strong passwords** - Minimum 6 characters, but longer is better
- **Store credentials securely** - Use environment variables, secrets managers, or encrypted configs
- Admin credentials can be updated by running the migration again with new ENV values (upsert behavior)

### Protected Actions

When logged in as admin, you can:
- Delete projects (cascades to all environments and drift checks)
- Delete environments (cascades to all drift checks)
- Exclude environments from dashboard metrics (see below)

### Excluding Environments From Dashboard Metrics

Test or short-lived environments can skew the dashboard charts. An admin can exclude an environment with the **Exclude from Metrics** button on its page, and include it again with **Include in Metrics**. `write` API tokens can set the same flag; see [API Usage](api-usage.md#update-an-environment).

- An excluded environment is left out of every dashboard chart and the stability score.
- It stays in every list: the dashboard table and status counts, the project page, its own page and the API, with its drift shown as normal.
- New checks are still recorded, and notifications are not affected.

Read-only operations (viewing dashboard, projects, environments, drift history) do not require authentication.

### Logging In

Access the login page at `/login`. After successful authentication, you'll be redirected to the dashboard with access to admin actions.

## GitHub OAuth Authentication

DriftHound supports GitHub OAuth for team-based authentication. Users can sign in with their GitHub account and be automatically assigned roles based on their GitHub team membership.

### Enabling GitHub OAuth

Set the following environment variables to enable GitHub OAuth:

```bash
GITHUB_OAUTH_ENABLED=true
GITHUB_CLIENT_ID=your-github-app-client-id
GITHUB_CLIENT_SECRET=your-github-app-client-secret
GITHUB_ORG=your-organization-name
```

### Team-to-Role Mapping

Map GitHub teams to DriftHound roles using these environment variables. You can specify multiple teams per role using comma-separated values:

```bash
# Single team per role
GITHUB_TEAM_ADMIN=platform-admins
GITHUB_TEAM_EDITOR=platform-editors
GITHUB_TEAM_VIEWER=platform-viewers

# Multiple teams per role (comma-separated)
GITHUB_TEAM_ADMIN=platform-admins,security-team,devops-leads
GITHUB_TEAM_EDITOR=developers,contractors
GITHUB_TEAM_VIEWER=read-only,auditors
```

**Notes:**
- At least one team mapping must be configured
- Multiple teams can be assigned to the same role using commas (e.g., `team1,team2,team3`)
- Team slugs are case-insensitive
- If a user belongs to multiple mapped teams with different roles, they receive the highest privilege role
- Users not in any configured team will be denied access

### Creating a GitHub OAuth App

1. Go to your GitHub organization settings
2. Navigate to **Developer settings** > **OAuth Apps** > **New OAuth App**
3. Configure the application:
   - **Application name**: DriftHound (or your preferred name)
   - **Homepage URL**: Your DriftHound instance URL (e.g., `https://drifthound.example.com`)
   - **Authorization callback URL**: `https://drifthound.example.com/auth/github/callback`
4. After creating, copy the **Client ID** and generate a **Client Secret**

### Required GitHub Permissions

The OAuth app requires access to:
- User's email address (`user:email` scope)
- User's organization team memberships (`read:org` scope)

Users will be prompted to authorize these permissions when signing in.

### How OAuth Authentication Works

1. User clicks "Sign in with GitHub" on the login page
2. User is redirected to GitHub to authorize access
3. After authorization, GitHub redirects back to DriftHound with an auth code
4. DriftHound exchanges the code for an access token
5. DriftHound fetches the user's profile and team memberships
6. Role is determined based on team mappings (highest privilege wins)
7. User account is created (if new) or updated with the mapped role
8. User is logged in and redirected to the dashboard

### Dual Authentication

Users authenticated via OAuth can also set a password for traditional email/password login. This allows flexibility in how users access the system.

### Example Configuration

```bash
# GitHub OAuth - Basic (single team per role)
GITHUB_OAUTH_ENABLED=true
GITHUB_CLIENT_ID=Iv1.a1b2c3d4e5f6g7h8
GITHUB_CLIENT_SECRET=secret123456789abcdef
GITHUB_ORG=my-company
GITHUB_TEAM_ADMIN=infrastructure-admins
GITHUB_TEAM_EDITOR=infrastructure-team
GITHUB_TEAM_VIEWER=developers

# GitHub OAuth - Advanced (multiple teams per role)
GITHUB_OAUTH_ENABLED=true
GITHUB_CLIENT_ID=Iv1.a1b2c3d4e5f6g7h8
GITHUB_CLIENT_SECRET=secret123456789abcdef
GITHUB_ORG=my-company
GITHUB_TEAM_ADMIN=infrastructure-admins,security-team
GITHUB_TEAM_EDITOR=infrastructure-team,platform-engineers,sre
GITHUB_TEAM_VIEWER=developers,contractors
```

## OpenID Connect (OIDC) Authentication

DriftHound can sign users in with any OpenID Connect identity provider (for example Keycloak, Authentik, Okta or Google Workspace). It is optional, off by default, and works next to password login and GitHub OAuth. One provider is supported per instance.

OIDC login uses [OmniAuth](https://github.com/omniauth/omniauth) with [omniauth_openid_connect](https://github.com/omniauth/omniauth_openid_connect): the authorization code flow with PKCE, `state` and `nonce`, provider discovery from `<issuer>/.well-known/openid-configuration`, and ID token validation (signature, issuer, audience and expiry) are handled by those gems.

### Enabling OIDC

```bash
OIDC_ENABLED=true
OIDC_ISSUER=https://login.example.com
OIDC_CLIENT_ID=drifthound
OIDC_CLIENT_SECRET=your-client-secret
OIDC_VIEWER_GROUPS=drift-viewers
```

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OIDC_ENABLED` | No | `false` | Set to `true` to show the SSO button and enable `/auth/oidc` |
| `OIDC_ISSUER` | When enabled | | Issuer URL of the provider, used for discovery |
| `OIDC_CLIENT_ID` | When enabled | | Client ID registered with the provider |
| `OIDC_CLIENT_SECRET` | When enabled | | Client secret registered with the provider |
| `OIDC_SCOPES` | No | `openid email profile` | Space- or comma-separated scopes; `openid` is always added |
| `OIDC_GROUPS_CLAIM` | No | `groups` | Claim in the ID token or userinfo response that holds the user's groups |
| `OIDC_ADMIN_GROUPS` | See below | | Comma-separated group values that grant the admin role |
| `OIDC_EDITOR_GROUPS` | See below | | Comma-separated group values that grant the editor role |
| `OIDC_VIEWER_GROUPS` | See below | | Comma-separated group values that grant the viewer role |
| `OIDC_DEFAULT_ROLE` | See below | | `viewer`, `editor` or `admin`, given to users in no mapped group. Unset means those users are refused |
| `OIDC_BUTTON_LABEL` | No | `Sign in with SSO` | Text of the login button |

When `OIDC_ENABLED=true`, the app refuses to boot if the issuer, client ID or client secret is missing, if `OIDC_DEFAULT_ROLE` is not a valid role, or if no group mapping and no default role is set.

### Registering DriftHound with your provider

Create a confidential web client with:

- **Redirect URI**: `APP_URL` followed by `/auth/oidc/callback`, for example `https://drifthound.example.com/auth/oidc/callback`. Set [`APP_URL`](#app_url) to the public URL of DriftHound.
- **Grant type**: authorization code
- **Claims**: `email`, and the groups claim named in `OIDC_GROUPS_CLAIM`

### Group-to-Role Mapping

```bash
OIDC_GROUPS_CLAIM=groups
OIDC_ADMIN_GROUPS=drift-admins
OIDC_EDITOR_GROUPS=drift-editors,release-managers
OIDC_VIEWER_GROUPS=drift-viewers
```

**Notes:**
- Group values are compared exactly as the provider sends them (case-sensitive). Some providers send group IDs instead of names; use whatever value appears in the claim.
- The role is set from the groups on every login, and the highest mapped role wins.
- Users in no mapped group are refused, unless `OIDC_DEFAULT_ROLE` is set.
- Some providers leave the groups claim out when a user is in many groups. Those users will match no group.

### How OIDC Users Are Matched

- Users are matched only on provider (`oidc`) and the `sub` claim. There is no linking by email.
- On first login a new user is created with the `email` claim (lowercased) and the mapped role.
- If that email already belongs to another DriftHound account (a password user, a GitHub user, or another OIDC subject), the login is refused with a message. Compare is case-insensitive. An admin can delete the old account if the person should sign in with OIDC instead.
- Logins without an `email` claim, or with `email_verified` set to `false`, are refused.
- The stored email is not changed on later logins.

### Example Configuration

```bash
APP_URL=https://drifthound.example.com
OIDC_ENABLED=true
OIDC_ISSUER=https://login.example.com
OIDC_CLIENT_ID=drifthound
OIDC_CLIENT_SECRET=your-client-secret
OIDC_SCOPES="openid email profile groups"
OIDC_GROUPS_CLAIM=groups
OIDC_ADMIN_GROUPS=drift-admins
OIDC_EDITOR_GROUPS=drift-editors
OIDC_VIEWER_GROUPS=drift-viewers
OIDC_BUTTON_LABEL="Sign in with Example SSO"
```

## Database Configuration

DriftHound uses PostgreSQL and supports multiple databases for different concerns (primary, cache, queue, cable).

### DRIFTHOUND_DATABASE_PASSWORD

PostgreSQL password for the production database.

**Required:** Yes (production only)
**Example:**

```bash
DRIFTHOUND_DATABASE_PASSWORD=your-secure-password
```

### DATABASE_URL (Alternative)

You can also provide a full PostgreSQL connection URL instead of individual settings.

**Required:** No (alternative to individual settings)
**Example:**

```bash
DATABASE_URL=postgresql://username:password@host:port/database_name
```

### RAILS_MAX_THREADS

Maximum number of database connections per process.

**Required:** No
**Default:** `5`
**Example:**

```bash
RAILS_MAX_THREADS=5
```

**Note:** This affects database connection pool size. Adjust based on your workload and available database connections.

### Database Configuration Files

Database settings are defined in [config/database.yml](../config/database.yml):

**Development:**
- Host: `localhost:5432`
- Database: `drifthound_development`
- Username: `drifthound`
- Password: `drifthound`

**Production:**
- Database: `drifthound_production` - Single database for all application data
- Username: `drifthound`
- Password: Set via `DRIFTHOUND_DATABASE_PASSWORD`

**Note:** DriftHound uses in-memory adapters for caching and background jobs. This keeps the setup simple and is sufficient for low to medium traffic applications. Only one database is needed.

## Data Retention

DriftHound automatically manages drift check data retention to prevent unbounded database growth while maintaining sufficient historical data for trend analysis and charts.

### DRIFT_CHECK_RETENTION_DAYS

Number of days to retain drift check history per environment.

**Required:** No
**Default:** `90`
**Example:**

```bash
DRIFT_CHECK_RETENTION_DAYS=90
```

**Behavior:**
- Drift checks older than this number of days are automatically deleted when new checks are created
- Retention is enforced per-environment (each environment maintains its own history)
- Set to `0` to disable retention and keep all checks indefinitely

**Recommended values based on check frequency:**

| Check Frequency | Recommended Retention | Approximate Checks/Env |
|-----------------|----------------------|------------------------|
| Multiple per day | 30-60 days | 120-240+ checks |
| Once daily | 90 days (default) | ~90 checks |
| Weekly | 180-365 days | 26-52 checks |

**Storage considerations:**
- Each drift check consumes approximately 1-2 KB of database storage
- With 100 environments running daily checks at 90-day retention: ~9,000 checks (~18 MB)
- Adjust based on your number of environments and check frequency

**Example configurations:**

```bash
# Default: 90 days (recommended for most users)
DRIFT_CHECK_RETENTION_DAYS=90

# Short retention for high-frequency checking
DRIFT_CHECK_RETENTION_DAYS=30

# Long retention for weekly checks
DRIFT_CHECK_RETENTION_DAYS=365

# Disable retention (keep all checks forever)
DRIFT_CHECK_RETENTION_DAYS=0
```

## Slack Notifications

DriftHound can send Slack notifications when drift is detected. Configuration can be done via environment variables or [config/notifications.yml](../config/notifications.yml).

### SLACK_NOTIFICATIONS_ENABLED

Enable or disable Slack notifications globally.

**Required:** Yes (to enable Slack)
**Default:** `false`
**Example:**

```bash
SLACK_NOTIFICATIONS_ENABLED=true
```

### SLACK_BOT_TOKEN

Your Slack Bot User OAuth Token.

**Required:** Yes (if Slack is enabled)
**Format:** Starts with `xoxb-`
**Example:**

```bash
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
```

**How to get a token:**
1. Go to https://api.slack.com/apps
2. Create a new app or select an existing one
3. Navigate to "OAuth & Permissions"
4. Add the following Bot Token Scopes:
   - `chat:write` - Post messages
   - `chat:write.public` - Post to public channels without joining
   - `chat:write.customize` - Message format customization
5. Install the app to your workspace
6. Copy the "Bot User OAuth Token"

### SLACK_DEFAULT_CHANNEL

Default Slack channel for drift notifications.

**Required:** No
**Default:** `#infrastructure-drift`
**Format:** Channel name with `#` prefix
**Example:**

```bash
SLACK_DEFAULT_CHANNEL=#infra-alerts
```

**Note:** This can be overridden per-environment via the API or CLI using the `--slack-channel` flag.

### NOTIFY_ON_FIRST_CHECK

Controls whether notifications are sent on the first drift check for new environments.

**Required:** No
**Default:** `false`
**Example:**

```bash
NOTIFY_ON_FIRST_CHECK=true
```

**Behavior:**

By default, new environments start with `unknown` status. The first drift check establishes a baseline and does not trigger notifications. This prevents notification spam when onboarding many environments.

When set to `true`, DriftHound will send notifications immediately if the first check detects drift or an error:

| First Check Result | `false` (default) | `true` |
|-------------------|-------------------|--------|
| `unknown → ok`    | No notification   | No notification |
| `unknown → drift` | No notification   | Drift Detected |
| `unknown → error` | No notification   | Error Detected |

**Use cases for enabling:**
- You want immediate alerts when adding new infrastructure monitoring
- Your environments should never have drift on first check
- You prefer proactive alerting over baseline establishment

### Notification Configuration File

Alternatively, you can configure notifications in [config/notifications.yml](../config/notifications.yml). Environment variables take precedence and are interpolated in the YAML file.

📖 See [Slack Notifications Guide](slack-notifications.md) for detailed setup instructions.

## Web Server Settings

DriftHound uses Puma as its web server.

### PORT

The port the web server listens on.

**Required:** No
**Default:** `3000`
**Example:**

```bash
PORT=8080
```

### RAILS_MAX_THREADS

Number of threads per Puma worker.

**Required:** No
**Default:** `3`
**Example:**

```bash
RAILS_MAX_THREADS=5
```

### WEB_CONCURRENCY

Number of Puma worker processes.

**Required:** No
**Default:** `0` (single process mode)
**Example:**

```bash
WEB_CONCURRENCY=2
```

**Recommendations:**
- Set to number of CPU cores for production
- Each worker consumes additional memory
- Not needed for small deployments

## Logging Configuration

### Log Output

In production, DriftHound logs to STDOUT with request ID tagging for easy integration with log aggregation services (e.g., CloudWatch, Datadog, Splunk).

### Silenced Endpoints

The `/up` health check endpoint is silenced by default to prevent log clutter. This is configured in [config/environments/production.rb](../config/environments/production.rb):

```ruby
config.silence_healthcheck_path = "/up"
```

## Background Jobs

DriftHound uses Rails' async adapter for background job processing. This means:
- Jobs (like sending Slack notifications) run in background threads within the web process
- No separate job processor or database is needed
- Simple deployment with automatic job processing
- Jobs are lost if the process crashes before completion (acceptable for notifications)

**Note:** For high-traffic applications where job durability is critical, you may want to switch to Solid Queue or Sidekiq in the future.

## Complete Example

### Production Environment Variables

Create a `.env` file or configure your deployment platform with these variables:

```bash
# Application
RAILS_ENV=production
APP_URL=https://drifthound.example.com
RAILS_LOG_LEVEL=info
SECRET_KEY_BASE=340b6113695da1baed5d5b7945bff4dc4ab86b75f602c5183624c1b87ffc17d192c18572196456bc3242b13ebf74ab75053c9c87ee2202d2718fbfe85e2ff94a

# Access Control (private by default)
PUBLIC_MODE=false
PLAN_OUTPUT_MIN_ROLE=viewer

# Admin Authentication (required in production)
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=your-secure-admin-password

# GitHub OAuth (optional)
GITHUB_OAUTH_ENABLED=true
GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret
GITHUB_ORG=your-organization
# Multiple teams per role supported (comma-separated)
GITHUB_TEAM_ADMIN=platform-admins,security-team
GITHUB_TEAM_EDITOR=platform-editors,developers
GITHUB_TEAM_VIEWER=read-only

# OpenID Connect (optional)
OIDC_ENABLED=true
OIDC_ISSUER=https://login.example.com
OIDC_CLIENT_ID=drifthound
OIDC_CLIENT_SECRET=your-oidc-client-secret
OIDC_ADMIN_GROUPS=drift-admins
OIDC_VIEWER_GROUPS=drift-viewers

# Database
DRIFTHOUND_DATABASE_PASSWORD=your-secure-db-password

# Data Retention
DRIFT_CHECK_RETENTION_DAYS=90

# Slack Notifications
SLACK_NOTIFICATIONS_ENABLED=true
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
SLACK_DEFAULT_CHANNEL=#infrastructure-drift
NOTIFY_ON_FIRST_CHECK=false

# Web Server
PORT=3000
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
```

## Verification

After configuration, verify your setup:

### Check Health Endpoint

```bash
curl http://localhost:3000/up
```

Should return `200 OK`.

### Test API Authentication

```bash
# Create a token via the web UI:
# 1. Log in as admin at /login
# 2. Navigate to API Tokens in the navigation bar
# 3. Create a new token and copy it

# Test API call
curl -X POST http://localhost:3000/api/v1/projects/test/environments/dev/checks \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "ok"}'
```

### Verify Slack Integration

Check Rails logs for notification configuration:

```bash
bin/rails runner "puts Rails.application.config.notifications.inspect"
```

## Troubleshooting

### Database Connection Issues

```bash
# Test database connection
bin/rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').to_a"
```

### Slack Notification Issues

```bash
# Check Slack configuration
bin/rails runner "puts Rails.application.config.notifications[:slack].inspect"

# Test Slack connection manually
bin/rails console
> client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
> client.chat_postMessage(channel: '#test', text: 'Test message')
```

### Port Already in Use

```bash
# Change the port
PORT=8080 bin/rails server
```

## See Also

- [Slack Notifications Setup](slack-notifications.md) - Detailed Slack configuration guide
- [API Usage](api-usage.md) - API token management
- [CLI Usage](cli-usage.md) - Using environment variables with the CLI
