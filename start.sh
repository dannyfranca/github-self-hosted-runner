#!/bin/bash

set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if runner is already configured
is_runner_configured() {
    [ -f "/home/docker/actions-runner/.runner" ]
}

# Function to remove runner configuration
remove_runner() {
    if is_runner_configured; then
        log "Removing existing runner configuration..."
        cd /home/docker/actions-runner
        
        # Try to remove with token if available
        if [ -n "${REG_TOKEN}" ]; then
            ./config.sh remove --unattended --token ${REG_TOKEN} || {
                log "Failed to remove with token, trying force removal..."
                rm -f .runner .credentials .credentials_rsaparams
            }
        else
            # Force remove configuration files if no token
            rm -f .runner .credentials .credentials_rsaparams
        fi
    fi
}

# Cleanup function for graceful shutdown
cleanup() {
    log "Received termination signal, cleaning up..."
    remove_runner
    exit 0
}

# Set up signal handlers
trap 'cleanup' INT TERM

# Generate unique runner name using prefix and hostname
RUNNER_NAME="${RUNNER_NAME_PREFIX:-runner}-$(hostname)"
log "Runner name: ${RUNNER_NAME}"

# Determine API endpoint based on runner type
if [ "${RUNNER_TYPE:-org}" = "repo" ]; then
    # Repository runner
    API_URL="https://api.github.com/repos/${REPOSITORY}/actions/runners/registration-token"
    RUNNER_URL="https://github.com/${REPOSITORY}"
else
    # Organization runner (default)
    API_URL="https://api.github.com/orgs/${REPOSITORY}/actions/runners/registration-token"
    RUNNER_URL="https://github.com/${REPOSITORY}"
fi

# Get registration token
log "Obtaining registration token..."
REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" ${API_URL} | jq .token --raw-output)

if [ -z "${REG_TOKEN}" ] || [ "${REG_TOKEN}" = "null" ]; then
    log "ERROR: Failed to obtain registration token. Check your ACCESS_TOKEN and REPOSITORY settings."
    exit 1
fi

cd /home/docker/actions-runner

# Always start fresh to avoid conflicts with other runners
remove_runner

# Configure the runner
log "Configuring runner..."
./config.sh \
    --url ${RUNNER_URL} \
    --token ${REG_TOKEN} \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS:-docker}" \
    --unattended \
    --ephemeral || {
        log "ERROR: Failed to configure runner"
        exit 1
    }

# Start the runner
log "Starting runner..."
./run.sh
