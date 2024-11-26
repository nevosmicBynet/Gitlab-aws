#!/bin/bash

# Exit on error
set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        log "SUCCESS: $1"
    else
        log "ERROR: $1"
        exit 1
    fi
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   log "This script must be run as root or with sudo privileges"
   exit 1
fi

# Get configuration values from command line arguments
DB_HOST="$1"
REDIS_HOST="$2"
EXTERNAL_URL="$3"
DB_NAME="$4"
DB_PASSWORD="$5"

if [ -z "$DB_HOST" ] || [ -z "$REDIS_HOST" ] || [ -z "$EXTERNAL_URL" ] || [ -z "$DB_NAME" ] || [ -z "$DB_PASSWORD" ]; then
    log "Usage: $0 <db_host> <redis_host> <external_url> <db_name> <db_password>"
    exit 1
fi

# Install dependencies
log "Installing dependencies..."
yum install -y curl policycoreutils-python openssh-server openssh-clients perl
check_status "Dependencies installation"

# Configure SSH
log "Configuring SSH..."
systemctl enable sshd
systemctl start sshd
check_status "SSH configuration"

# Check and configure firewall
log "Checking firewall status..."
if ! command -v firewall-cmd &> /dev/null; then
    log "firewalld not found. Installing..."
    yum install -y firewalld
    check_status "firewalld installation"
fi

# Start and enable firewalld if not running
if ! systemctl is-active --quiet firewalld; then
    log "Starting firewalld service..."
    systemctl start firewalld
    systemctl enable firewalld
    check_status "firewalld service activation"
fi

log "Configuring firewall..."
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
systemctl reload firewalld
check_status "Firewall configuration"

# Install and configure Postfix
log "Installing Postfix..."
yum install -y postfix
systemctl enable postfix
systemctl start postfix
check_status "Postfix installation and configuration"

# Add GitLab repository
log "Adding GitLab repository..."
curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.rpm.sh | bash
check_status "GitLab repository addition"

# Install GitLab
log "Installing GitLab..."
EXTERNAL_URL="${EXTERNAL_URL}" yum install -y gitlab-ee
check_status "GitLab installation"

# Configure GitLab
log "Configuring GitLab..."
cat > /etc/gitlab/gitlab.rb << EOF
external_url '${EXTERNAL_URL}'

# Disable the built-in Postgres
postgresql['enable'] = false

# Configure external Postgres
gitlab_rails['db_adapter'] = "postgresql"
gitlab_rails['db_encoding'] = "unicode"
gitlab_rails['db_database'] = "${DB_NAME}"
gitlab_rails['db_username'] = "gitlab"
gitlab_rails['db_password'] = "${DB_PASSWORD}"
gitlab_rails['db_host'] = "${DB_HOST}"

# Disable the built-in Redis
redis['enable'] = false

# Configure external Redis
gitlab_rails['redis_host'] = "${REDIS_HOST}"
gitlab_rails['redis_port'] = 6379

# Add any additional configurations here
EOF

# Reconfigure GitLab
log "Reconfiguring GitLab..."
gitlab-ctl reconfigure
check_status "GitLab reconfiguration"

# Display initial root password location
log "Installation completed successfully!"
log "Your initial root password can be found in /etc/gitlab/initial_root_password"
log "Please save this password and delete the file for security"
log "The password will be automatically deleted in 24 hours"

# Display GitLab URL
log "GitLab has been configured to run at: ${EXTERNAL_URL}"
log "Please allow a few minutes for GitLab to start up"
log "You can monitor the startup process with: sudo gitlab-ctl status"