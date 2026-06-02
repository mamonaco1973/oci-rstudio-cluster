#!/bin/bash
set -euo pipefail

# ==============================================================================
# 01-directory outputs
# ==============================================================================

DC_IP=$(cd 01-directory && terraform output -raw dc_private_ip 2>/dev/null || echo "")
BASTION_ID=$(cd 01-directory && terraform output -raw bastion_id 2>/dev/null || echo "")
NETBIOS=$(cd 01-directory && terraform output -raw netbios 2>/dev/null || echo "MCLOUD")

# ==============================================================================
# 03-servers outputs
# ==============================================================================

XUBUNTU_IP=$(cd 03-servers && terraform output -raw xubuntu_public_ip 2>/dev/null || echo "")
WINDOWS_IP=$(cd 03-servers && terraform output -raw windows_public_ip 2>/dev/null || echo "")

# ==============================================================================
# Summary banner
# ==============================================================================

echo ""
echo "============================================================================"
echo "Xubuntu XRDP - Deployment Summary"
echo "============================================================================"
echo ""
echo "  Domain Controller (private)"
echo "    IP       : ${DC_IP:-not deployed}"
echo "    Connect  : ./connect.sh"
echo ""
echo "  Xubuntu Desktop (public)"
echo "    IP       : ${XUBUNTU_IP:-not deployed}"
echo "    RDP      : Connect to ${XUBUNTU_IP:-<ip>}:3389 as rpatel"
echo "    SSH      : ssh -i 01-directory/keys/Private_Key ubuntu@${XUBUNTU_IP:-<ip>}"
echo "    AD user  : ./get_password.sh rpatel"
echo ""
echo "  Windows Client (public)"
echo "    IP       : ${WINDOWS_IP:-not deployed}"
echo "    Connect  : RDP to ${WINDOWS_IP:-<ip>} as ${NETBIOS}\\Admin"
echo ""
echo "  Passwords  : ./get_password.sh <user>"
echo "               users: admin jsmith edavis rpatel akumar"
echo ""
echo "============================================================================"
echo ""
