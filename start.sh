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

# Check if runner is already configured
if is_runner_configured; then
    log "Runner is already configured. Checking if it's still valid..."
    
    # Try to run the runner directly
    ./run.sh &
    RUNNER_PID=$!
    
    # Give it a few seconds to see if it starts successfully
    sleep 5
    
    if kill -0 $RUNNER_PID 2>/dev/null; then
        log "Existing runner configuration is valid, reusing it..."
        wait $RUNNER_PID
    else
        log "Existing runner configuration is invalid, reconfiguring..."
        remove_runner
        
        # Configure the runner
        log "Configuring runner..."
        ./config.sh \
            --url ${RUNNER_URL} \
            --token ${REG_TOKEN} \
            --labels "${RUNNER_LABELS:-docker}" \
            --unattended \
            --replace || {
                log "ERROR: Failed to configure runner"
                exit 1
            }
        
        # Start the runner
        log "Starting runner..."
        ./run.sh
    fi
else
    # Configure the runner
    log "Configuring new runner..."
    ./config.sh \
        --url ${RUNNER_URL} \
        --token ${REG_TOKEN} \
        --labels "${RUNNER_LABELS:-docker}" \
        --unattended || {
            log "ERROR: Failed to configure runner"
            exit 1
        }
    
    # Start the runner
    log "Starting runner..."
    ./run.sh
fi
