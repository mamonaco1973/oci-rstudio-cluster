#!/bin/bash
set -euo pipefail

# ==============================================================================
# 01-directory outputs
# ==============================================================================

DC_IP=$(cd 01-directory && terraform output -raw dc_private_ip 2>/dev/null || echo "")
NETBIOS=$(cd 01-directory && terraform output -raw netbios 2>/dev/null || echo "MCLOUD")

# ==============================================================================
# 02-servers outputs
# ==============================================================================

LINUX_IP=$(cd 02-servers && terraform output -raw linux_public_ip 2>/dev/null || echo "")
WINDOWS_IP=$(cd 02-servers && terraform output -raw windows_public_ip 2>/dev/null || echo "")

# ==============================================================================
# 04-cluster outputs
# ==============================================================================

LB_IP=$(cd 04-cluster && terraform output -raw lb_public_ip 2>/dev/null || echo "")

# ==============================================================================
# Summary banner
# ==============================================================================

echo ""
echo "============================================================================"
echo "RStudio Cluster - Deployment Summary"
echo "============================================================================"
echo ""
echo "  Domain Controller (private)"
echo "    IP       : ${DC_IP:-not deployed}"
echo "    Connect  : ./connect.sh"
echo ""
echo "  Linux Samba Gateway (public)"
echo "    IP       : ${LINUX_IP:-not deployed}"
echo "    SSH      : ssh -i 01-directory/keys/Private_Key ubuntu@${LINUX_IP:-<ip>}"
echo "    NFS/SMB  : Z: drive on Windows maps to \\\\${LINUX_IP:-<ip>}\\nfs"
echo ""
echo "  Windows AD Client (public)"
echo "    IP       : ${WINDOWS_IP:-not deployed}"
echo "    RDP      : Connect to ${WINDOWS_IP:-<ip>} as ${NETBIOS}\\Admin"
echo ""
echo "  RStudio Cluster (via Load Balancer)"
echo "    URL      : http://${LB_IP:-<lb-ip>}"
echo "    Sign in  : AD credentials (e.g., rpatel)"
echo "    AD user  : ./get_password.sh rpatel"
echo ""
echo "  Passwords  : ./get_password.sh <user>"
echo "               users: admin jsmith edavis rpatel akumar"
echo ""
echo "============================================================================"
echo ""
