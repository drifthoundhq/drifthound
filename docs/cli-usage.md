# CLI Usage

DriftHound provides a Ruby CLI to automate drift checks and report results to the server. This is ideal for CI/CD pipelines.

## Installation

### Quick Install

You can install the CLI directly without cloning the repo:

```sh
sudo curl -L https://raw.githubusercontent.com/drifthoundhq/drifthound/main/bin/drifthound-cli -o /usr/local/bin/drifthound && sudo chmod +x /usr/local/bin/drifthound
```

This will make the `drifthound` command available globally.

### Docker

You can also run the CLI directly from the published Docker image, without installing Ruby or dependencies locally:

```sh
docker run --rm \
  -v "$(pwd)":/infra \
  -w /infra \
  ghcr.io/drifthoundhq/drifthound:<tag> \
  bin/drifthound-cli --tool=terraform|terragrunt|opentofu \
    --project=PROJECT_KEY \
    --environment=ENV_KEY \
    --token=API_TOKEN \
    --api-url=http://your-drifthound-server \
    --dir=.
```

Replace `<tag>` with the desired image version (e.g., `v0.1.0`).

This mounts your current directory into the container and runs the CLI as if it were installed locally.

## Basic Usage

```sh
drifthound --tool=terraform|terragrunt|opentofu \
  --project=PROJECT_KEY \
  --environment=ENV_KEY \
  --token=API_TOKEN \
  --api-url=http://localhost:3000 \
  --dir=PATH_TO_INFRA_DIR
```

### Example

```sh
drifthound --tool=terragrunt --project=shipping --environment=production \
  --token=YOUR_API_TOKEN --api-url=http://localhost:3000 --dir=.
```

### Docker Example

```sh
docker run --rm -v "$(pwd)":/infra -w /infra ghcr.io/drifthoundhq/drifthound:v0.1.0 \
  bin/drifthound-cli --tool=terragrunt --project=shipping --environment=production \
  --token=YOUR_API_TOKEN --api-url=http://localhost:3000 --dir=.
```

## Command Line Options

| Option            | Required | Description                                  |
|-------------------|----------|----------------------------------------------|
| `--tool`          | Yes      | `terraform`, `terragrunt`, or `opentofu`     |
| `--project`       | Yes      | Project key                                  |
| `--environment`   | Yes      | Environment key                              |
| `--environment-name` | No    | Environment display name. Defaults to the titleized environment key. When given, it also renames an existing environment. |
| `--token`         | Yes      | API token                                    |
| `--api-url`       | Yes      | DriftHound API base URL                      |
| `--dir`           | No       | Directory to run the tool in (default: `.`). Stored in environment on first call only; update via GUI. |
| `--repository`    | No       | Repository URL. **Auto-detected from git** if not provided. Stored in project on first call only; update via GUI. |
| `--branch`        | No       | Repository branch. **Auto-detected from git** if not provided. Stored on every check, and in the project on first call only. |
| `--slack-channel` | No       | Slack Channel to send notifications to       |

## How It Works

The CLI will:
1. **Auto-detect repository URL and branch** from git (if running in a git repository)
2. Run the specified tool's plan command (e.g., `terraform plan`, `terragrunt plan`)
3. Parse the output to extract drift information
4. Send a drift report to the DriftHound API

The payload includes:
- Drift status (`ok`, `drift`, `error`, `unknown`)
- Resource counts (add, change, destroy)
- Execution duration
- Full plan output
- Working directory (stored in the environment record)
- Repository URL (auto-detected or provided, stored in the project record)
- Branch (auto-detected or provided, stored in the project record)

### Git Auto-Detection

The CLI automatically detects:
- **Repository URL**: From `git remote get-url origin`. SSH URLs are converted to HTTPS format.
- **Branch**: From the current git branch (`git rev-parse --abbrev-ref HEAD`).

You can override auto-detection by explicitly providing `--repository` or `--branch`.

## Advanced Configuration

### Using Environment Variables

Instead of passing options via command line, you can use environment variables:

```sh
export DRIFTHOUND_TOOL=terraform
export DRIFTHOUND_PROJECT=my-infrastructure
export DRIFTHOUND_ENVIRONMENT=production
export DRIFTHOUND_TOKEN=your-api-token
export DRIFTHOUND_API_URL=https://drifthound.example.com
export DRIFTHOUND_SLACK_CHANNEL=#infra-alerts

drifthound --dir=./terraform
```

### Multiple Environments

You can run checks for multiple environments in sequence:

```sh
for env in dev staging production; do
  drifthound --tool=terraform \
    --project=my-infrastructure \
    --environment=$env \
    --token=$DRIFTHOUND_TOKEN \
    --api-url=$DRIFTHOUND_URL \
    --dir=./terraform/$env
done
```

### Conditional Slack Notifications

Only send Slack notifications for production:

```sh
if [ "$ENVIRONMENT" = "production" ]; then
  SLACK_OPTION="--slack-channel=#infra-alerts"
else
  SLACK_OPTION=""
fi

drifthound --tool=terraform \
  --project=my-infrastructure \
  --environment=$ENVIRONMENT \
  --token=$DRIFTHOUND_TOKEN \
  --api-url=$DRIFTHOUND_URL \
  --dir=./terraform \
  $SLACK_OPTION
```

## Supported Tools

### Terraform

```sh
drifthound --tool=terraform \
  --project=my-project \
  --environment=production \
  --token=$TOKEN \
  --api-url=$URL \
  --dir=./terraform
```

The CLI runs `terraform plan -detailed-exitcode` and parses the output.

### Terragrunt

```sh
drifthound --tool=terragrunt \
  --project=my-project \
  --environment=production \
  --token=$TOKEN \
  --api-url=$URL \
  --dir=./terragrunt
```

The CLI runs `terragrunt plan -detailed-exitcode` and parses the output.

### OpenTofu

```sh
drifthound --tool=opentofu \
  --project=my-project \
  --environment=production \
  --token=$TOKEN \
  --api-url=$URL \
  --dir=./tofu
```

The CLI runs `tofu plan -detailed-exitcode` and parses the output.

## Best Practices

1. **Run checks on a schedule** - Set up cron jobs or CI/CD schedules to check for drift regularly (e.g., every 6 hours)
2. **Use separate environments** - Create different environment keys for dev, staging, and production
3. **Store tokens securely** - Use CI/CD secrets or environment variables, never hardcode tokens
4. **Configure Slack channels per environment** - Use different channels for production vs. non-production alerts
5. **Run in read-only mode** - The CLI only runs `plan`, never `apply`, ensuring safe drift detection
6. **Review raw output** - Check the DriftHound dashboard for full plan output when investigating drift

## Troubleshooting

### Authentication Errors

If you get `401 Unauthorized`:
- Verify your token is correct
- Check that the token hasn't been revoked
- Generate a new token: `bin/rails api_tokens:generate[new-token]`

### Tool Not Found

If you get `command not found` errors:
- Ensure Terraform/Terragrunt/OpenTofu is installed and in your PATH
- Use the Docker image which includes all tools

### API Connection Errors

If you can't connect to the API:
- Verify the API URL is correct and reachable
- Check network/firewall rules
- Ensure the DriftHound server is running

## See Also

- [API Reference](api-usage.md) - Direct API usage without the CLI
- [Slack Notifications](slack-notifications.md) - Configure Slack alerts
