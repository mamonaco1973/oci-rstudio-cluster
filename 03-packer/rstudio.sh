#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# Install R Base
# ==============================================================================

apt-get update -y
apt-get install -y software-properties-common dirmngr

# This section determines which version of R gets installed
# Add CRAN repo to get latest R instead of Ubuntu's older bundled version

wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
  | gpg --dearmor -o /usr/share/keyrings/r-project.gpg
echo "deb [signed-by=/usr/share/keyrings/r-project.gpg] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" \
  | tee /etc/apt/sources.list.d/r-project.list

apt-get update -y
apt-get install -y r-base r-base-dev

# ==============================================================================
# Install RStudio Server Community Edition
# ==============================================================================

cd /tmp
wget -q https://rstudio.org/download/latest/stable/server/jammy/rstudio-server-latest-amd64.deb
apt-get install -y ./rstudio-server-latest-amd64.deb
rm -f rstudio-server-latest-amd64.deb

# ==============================================================================
# Configure PAM for RStudio to authenticate via SSSD / AD
# ==============================================================================

cat <<'EOF' | tee /etc/pam.d/rstudio > /dev/null
# PAM configuration for RStudio Server — delegates to common-auth (SSSD/AD)
auth     include   common-auth
auth     [success=ok new_authtok_reqd=ok ignore=ignore user_unknown=bad default=die] pam_exec.so /etc/pam.d/rstudio-mkhomedir.sh
account  include   common-account
password include   common-password
session  include   common-session
EOF

# Forces a login shell for the AD user, which triggers pam_mkhomedir to
# create their home directory on FSS the first time they sign in to RStudio.
cat <<'EOF' | tee /etc/pam.d/rstudio-mkhomedir.sh > /dev/null
#!/bin/bash
su -c "exit" $PAM_USER
EOF

chmod +x /etc/pam.d/rstudio-mkhomedir.sh

echo "=== rstudio.sh completed successfully ==="
