# GitHub Self-Hosted Runner

A Docker-based self-hosted GitHub Actions runner that can be easily deployed and scaled.

## Prerequisites

- Docker and Docker Compose installed
- GitHub Personal Access Token with appropriate permissions (see detailed instructions below)
- **Organization Owner** access (for organization-level runners) or **Admin access** to repository (for repository-level runners)

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd github-self-hosted-runner
```

### 2. Generate GitHub Personal Access Token

**Requirements:**
- **Organization runners**: You must be an **organization owner** (not just a member)
- **Repository runners**: You must have **admin access** to the repository

#### Recommended: Fine-grained Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Click "Generate new token"
3. Give it a descriptive name (e.g., "Self-hosted runners")
4. Set expiration (recommend 90 days or less for security)
5. **Select resource owner:**
   - **Organization runners**: Select your organization
   - **Repository runners**: Select specific repositories
6. **Set permissions:**
   - **Organization runners**: Under "Organization permissions", set "Self-hosted runners" to "Read and write"
   - **Repository runners**: Under "Repository permissions", set "Administration" to "Write"
7. Submit for approval if required by your organization
8. **Copy the token immediately** (you won't see it again)

#### Alternative: Classic Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name and set expiration
4. **Select required scopes:**
   - **Organization runners**: `admin:org` (and optionally `repo`)
   - **Repository runners**: `repo`
5. Generate token and **copy immediately**

### 3. Configure Environment Variables

Create a `.env` file based on the provided schema:

```bash
cp .env.schema .env
```

Edit the `.env` file with your configuration:

```env
# Runner type: 'org' for organization runners, 'repo' for repository runners
RUNNER_TYPE=org

# For organization runner: YOUR_ORG_NAME
# For repository runner: YOUR_USERNAME/YOUR_REPO
REPOSITORY=your-org-or-repo
RUNNER_LABELS=docker,linux
RUNNER_NAME_PREFIX=prod
ACCESS_TOKEN=your_github_personal_access_token
```

### 4. Deploy the Runner

Start a single runner:
```bash
make up
```

Start multiple runners (e.g., 3 runners):
```bash
make up workers=3
```

### 5. Stop the Runner

```bash
make down
```

## File Structure

- `Dockerfile` - Ubuntu-based image with GitHub Actions runner
- `compose.yml` - Docker Compose configuration
- `start.sh` - Runner registration and startup script
- `Makefile` - Convenient commands for managing runners
- `.env.schema` - Environment variable template

## Configuration Options

### Environment Variables

- `RUNNER_TYPE` - Runner type: `org` for organization runners, `repo` for repository runners (default: `org`)
- `REPOSITORY` - GitHub organization or repository (format: `org-name` or `owner/repo`)
- `ACCESS_TOKEN` - GitHub Personal Access Token
- `RUNNER_LABELS` - Comma-separated list of runner labels (default: `docker`)
- `RUNNER_NAME_PREFIX` - Prefix for runner names (default: `runner`). Each runner will be named as `{prefix}-{hostname}`

### Running Multiple Runners

You can run multiple runners simultaneously using Docker Compose scaling:

```bash
make up workers=5  # Starts 5 runners
```

**Important Notes for Multiple Runners:**
- Each runner runs in **ephemeral mode** and will be automatically unregistered after completing a job
- No persistent volumes are used to avoid configuration conflicts between runners
- Each runner gets a unique name using the format `{RUNNER_NAME_PREFIX}-{container_hostname}`
- All runners share the same labels and configuration from your `.env` file
- Runners are stateless and disposable - perfect for scaling up/down based on demand

Example: Scale up to handle more workload
```bash
# Start with 3 runners
make up workers=3

# Scale up to 10 runners
docker compose up -d --scale runner=10

# Scale down to 5 runners
docker compose up -d --scale runner=5
```

### Runner Identification

Each runner container is uniquely identified through:

1. **Runner Name**: Automatically generated as `{RUNNER_NAME_PREFIX}-{hostname}` (e.g., `prod-abc123`)
2. **Docker Labels**: Containers are labeled for easy filtering and identification:
   - `com.github.runner.repository` - The GitHub repository/organization
   - `com.github.runner.type` - Runner type (org or repo)
   - `com.github.runner.labels` - The runner labels
   - `com.github.runner.prefix` - The runner name prefix

Example: View all runners with their labels:
```bash
docker ps --filter "label=com.github.runner.repository" --format "table {{.Names}}\t{{.Label \"com.github.runner.prefix\"}}\t{{.Label \"com.github.runner.repository\"}}"
```

## How It Works

1. The Docker image is based on Ubuntu 22.04
2. Downloads and installs GitHub Actions runner (v2.325.0)
3. Uses your ACCESS_TOKEN to get a registration token from GitHub API
4. Registers the runner with your GitHub organization/repository based on RUNNER_TYPE
5. Automatically unregisters when the container stops
6. Supports scaling to multiple runners using Docker Compose

## Troubleshooting

### Runner Not Registering
- **Verify your ACCESS_TOKEN has the correct permissions:**
  - Organization runners: `admin:org` scope
  - Repository runners: `repo` scope
- **Check user permissions:**
  - Organization runners: You must be an organization owner
  - Repository runners: You must have admin access to the repository
- Check that REPOSITORY is in the correct format
- Ensure RUNNER_TYPE matches your intended setup (`org` or `repo`)
- Review container logs: `docker compose logs runner`

### Permission Issues
- **"Resource not accessible by personal access token"**: Your user account lacks the required permissions
- **Organization runners**: Ensure you're an organization owner, not just a member
- **Repository runners**: Ensure you have admin access to the repository
- Verify the token hasn't expired

### Testing Your Token

You can test if your token works by running the appropriate command based on your `RUNNER_TYPE`:

**For organization runners (`RUNNER_TYPE=org`):**
```bash
curl -X POST \
  -H "Authorization: token YOUR_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/orgs/YOUR_ORG/actions/runners/registration-token
```

**For repository runners (`RUNNER_TYPE=repo`):**
```bash
curl -X POST \
  -H "Authorization: token YOUR_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/OWNER/REPO/actions/runners/registration-token
```

Both commands should return a JSON response with a `token` field if successful.

## Security Notes

- **Never commit your `.env` file** (it's already in `.gitignore`)
- **Store tokens securely** - use environment variables or secrets management
- **Rotate your ACCESS_TOKEN regularly** (every 90 days recommended)
- **Use minimum required permissions** - don't grant more access than needed
- Consider using GitHub's fine-grained personal access tokens for better security
- **Organization owners only**: Fine-grained tokens for organization runners require organization owner privileges

## Token Permission Summary

| Runner Type  | Token Type       | Required Permissions          | User Requirements  |
| ------------ | ---------------- | ----------------------------- | ------------------ |
| Organization | Classic PAT      | `admin:org`                   | Organization Owner |
| Organization | Fine-grained PAT | "Self-hosted runners" (write) | Organization Owner |
| Repository   | Classic PAT      | `repo`                        | Repository Admin   |
| Repository   | Fine-grained PAT | "Administration" (write)      | Repository Admin   |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
