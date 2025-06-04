# GitHub Self-Hosted Runner

A Docker-based self-hosted GitHub Actions runner that can be easily deployed and scaled.

## Prerequisites

- Docker and Docker Compose installed
- GitHub Personal Access Token with appropriate permissions
- Linux/macOS/Windows with WSL2

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd github-self-hosted-runner
```

### 2. Configure Environment Variables

Create a `.env` file based on the provided schema:

```bash
cp .env.schema .env
```

Edit the `.env` file with your configuration:

```env
# For organization runner: YOUR_ORG_NAME
# For repository runner: YOUR_USERNAME/YOUR_REPO
REPOSITORY=your-org-or-repo
RUNNER_LABELS=wsl2,docker,self-hosted,linux
ACCESS_TOKEN=your_github_personal_access_token
```

### 3. Generate GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate a new token with the following scopes:
   - For organization runners: `admin:org`
   - For repository runners: `repo`
3. Copy the token and add it to your `.env` file

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

- `REPOSITORY` - GitHub organization or repository (format: `org-name` or `username/repo`)
- `ACCESS_TOKEN` - GitHub Personal Access Token
- `RUNNER_LABELS` - Comma-separated list of runner labels (default: `wsl2,docker,self-hosted,linux`)

### Scaling

You can run multiple runners by using the `workers` parameter:
```bash
make up workers=5  # Starts 5 runners
```

## How It Works

1. The Docker image is based on Ubuntu 22.04
2. Downloads and installs GitHub Actions runner (v2.325.0)
3. Registers the runner with your GitHub organization/repository
4. Automatically unregisters when the container stops
5. Supports scaling to multiple runners using Docker Compose

## Troubleshooting

### Runner Not Registering
- Verify your ACCESS_TOKEN has the correct permissions
- Check that REPOSITORY is in the correct format
- Review container logs: `docker compose logs runner`

### Permission Issues
- Ensure the ACCESS_TOKEN has `admin:org` scope for organization runners
- For repository runners, ensure `repo` scope is enabled

## Security Notes

- Never commit your `.env` file (it's already in `.gitignore`)
- Rotate your ACCESS_TOKEN regularly
- Use GitHub's fine-grained personal access tokens when possible

## License

[Add your license here]