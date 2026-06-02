#!/bin/bash
set -euo pipefail

VALID_USERS="admin ubuntu jsmith edavis rpatel akumar windows_local_admin"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <user>"
  echo "Valid users: $VALID_USERS"
  exit 1
fi

USER="$1"

case "$USER" in
  admin|ubuntu)        OUTPUT="admin_password" ;;
  jsmith)              OUTPUT="jsmith_password" ;;
  edavis)              OUTPUT="edavis_password" ;;
  rpatel)              OUTPUT="rpatel_password" ;;
  akumar)              OUTPUT="akumar_password" ;;
  windows_local_admin) OUTPUT="windows_local_admin_password" ;;
  *)
    echo "ERROR: Unknown user '$USER'"
    echo "Valid users: $VALID_USERS"
    exit 1
    ;;
esac

PASSWORD=$(cd 01-directory && terraform output -raw "$OUTPUT" 2>/dev/null)
DNS_ZONE=$(cd 01-directory && terraform output -raw dns_zone 2>/dev/null)

if [ -z "$PASSWORD" ]; then
  echo "ERROR: could not read $OUTPUT from tfstate — has 01-directory been applied?"
  exit 1
fi

if [ "$USER" = "windows_local_admin" ]; then
  echo "Username : windows_local_admin (local account)"
elif [ "$USER" = "ubuntu" ]; then
  echo "Username : ubuntu (local account)"
else
  echo "Username : ${USER}@${DNS_ZONE}"
fi
echo "Password : ${PASSWORD}"
