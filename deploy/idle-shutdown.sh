#!/bin/bash
# Deallocates this VM via its own system-assigned managed identity when Caddy has seen no
# requests for IDLE_MINUTES. Requires:
#   - System-assigned identity enabled on the VM (az vm identity assign)
#   - That identity granted a role with just Microsoft.Compute/virtualMachines/deallocate/action
#     + .../read + .../instanceView/read, scoped to this VM only (see deploy/README.md)
# Installed as a systemd timer (see deploy/idle-shutdown.timer / .service) running every 5 min.
set -euo pipefail

IDLE_MINUTES=30
SUBSCRIPTION_ID="7c423ef4-a02f-45ad-868f-a360784946e9"
RESOURCE_GROUP="microservices-task-rg"
VM_NAME="microservices-vm"
COMPOSE_FILE="/home/azureuser/microservices-project/docker-compose.prod.yml"

LAST_TS=$(docker compose -f "$COMPOSE_FILE" logs --tail 200 caddy 2>/dev/null |
	grep -o '"ts":[0-9.]*' | tail -1 | cut -d: -f2 | cut -d. -f1 || true)

if [ -z "$LAST_TS" ]; then
	echo "$(date -Is) no Caddy log activity seen yet — skipping idle check this run"
	exit 0
fi

NOW=$(date +%s)
IDLE_SECONDS=$((NOW - LAST_TS))
IDLE_THRESHOLD=$((IDLE_MINUTES * 60))

if [ "$IDLE_SECONDS" -lt "$IDLE_THRESHOLD" ]; then
	echo "$(date -Is) last request ${IDLE_SECONDS}s ago (threshold ${IDLE_THRESHOLD}s) — staying up"
	exit 0
fi

echo "$(date -Is) idle for ${IDLE_SECONDS}s (>${IDLE_THRESHOLD}s) — deallocating"

TOKEN=$(curl -sf -H "Metadata: true" \
	"http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F" |
	grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
	echo "$(date -Is) failed to get IMDS token, aborting" >&2
	exit 1
fi

curl -sf -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Length: 0" \
	"https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$VM_NAME/deallocate?api-version=2023-09-01"

echo "$(date -Is) deallocate request sent"
