#!/bin/bash

set -e

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

REG_TOKEN=$(curl -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" ${API_URL} | jq .token --raw-output)

cd /home/docker/actions-runner

./config.sh  \
    --url ${RUNNER_URL} \
    --token ${REG_TOKEN} \
    --labels "${RUNNER_LABELS:-wsl2,docker,self-hosted}"

cleanup() {
    echo "Removing runner..."
    ./config.sh remove --unattended --token ${REG_TOKEN}
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
