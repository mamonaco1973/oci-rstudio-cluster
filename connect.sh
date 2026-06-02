#!/bin/bash
set -uo pipefail

LOCAL_PORT=2222

# Fall back to OCI CLI lookup if the apply is still in-progress and outputs
# aren't written to state yet (Terraform only commits outputs on apply completion).
BASTION_ID="${BASTION_ID:-$(cd 01-directory && terraform output -raw bastion_id 2>/dev/null)}"
if [ -z "$BASTION_ID" ]; then
  echo "terraform output missing — looking up bastion via OCI CLI..."
  BASTION_ID=$(oci bastion bastion list \
    --compartment-id "${OCI_COMPARTMENT_ID:-$(awk -F= '/^tenancy/{print $2}' ~/.oci/config | tr -d ' ')}" \
    --all \
    --query 'data[0].id' \
    --raw-output)
fi
if [ -z "$BASTION_ID" ]; then
  echo "ERROR: could not determine bastion OCID" >&2
  exit 1
fi

DC_IP=$(cd 01-directory && terraform output -raw dc_private_ip 2>/dev/null)
TARGET_IP="${1:-$DC_IP}"

echo "Target: $TARGET_IP"

# Generate a temporary RSA key for the bastion tunnel.
# OCI Bastion rejects ECDSA — temp RSA key avoids dependency on the
# Terraform-managed key pair entirely.
TMP_DIR=$(mktemp -d /tmp/bastion_XXXXXX)
TMP_KEY="$TMP_DIR/key"
ssh-keygen -t rsa -b 4096 -f "$TMP_KEY" -N "" -q
chmod 600 "$TMP_KEY"

cleanup() {
  rm -rf "$TMP_DIR"
  kill "$TUNNEL_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Creating bastion session..."

TARGET_DETAILS="{\"targetResourcePrivateIpAddress\": \"${TARGET_IP}\", \"targetResourcePort\": 22, \"sessionType\": \"PORT_FORWARDING\"}"

SESSION_JSON=$(oci bastion session create \
  --bastion-id "$BASTION_ID" \
  --target-resource-details "$TARGET_DETAILS" \
  --key-type PUB \
  --ssh-public-key-file "${TMP_KEY}.pub" \
  --session-ttl-in-seconds 10800)

SESSION_ID=$(echo "$SESSION_JSON" | jq -r '.data.id')
echo "Session: $SESSION_ID"
echo "Waiting for ACTIVE..."

while true; do
  SESSION_DATA=$(oci bastion session get --session-id "$SESSION_ID")
  STATE=$(echo "$SESSION_DATA" | jq -r '.data["lifecycle-state"]')
  echo "  $STATE"
  [ "$STATE" = "ACTIVE" ] && break
  sleep 10
done
sleep 15

TUNNEL_CMD=$(echo "$SESSION_DATA" | jq -r '.data["ssh-metadata"].command' \
  | sed "s|<privateKey>|${TMP_KEY}|g" \
  | sed "s|<localPort>|${LOCAL_PORT}|g")

echo "Opening tunnel..."
# Kill any stale tunnel from a previous run before binding the port
fuser -k "${LOCAL_PORT}/tcp" >/dev/null 2>&1 || true
sleep 1
eval "$TUNNEL_CMD -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" &
TUNNEL_PID=$!
sleep 3

ssh -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i 01-directory/keys/Private_Key \
  -p "$LOCAL_PORT" \
  ubuntu@localhost
