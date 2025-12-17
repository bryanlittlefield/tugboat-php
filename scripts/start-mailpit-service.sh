#!/bin/bash

# MailPit Service Setup Script

# Description: This script sets up and configures the MailPit service on a Linux system.
# It creates the necessary log and service config files, sets permissions, and starts the service.
# The script also provides an alternative method to run the MailPit server directly from the command line and log its output.

# Steps:
# 1. Remove any existing mailpit.service file.
# 2. Create a new mailpit.service file and a mailpit.log file.
# 3. Push the content into the mailpit.service file with the necessary configuration.
# 4. Set permissions for the mailpit.service file.
# 5. Reload the systemd manager configuration.
# 6. Enable the mailpit service.
# 7. Start the mailpit service and check its status.

# Usage:
# - Run the script as root or with sudo privileges.

# Example:
# sudo bash start-mailpit-service.sh

echo "📬 Setting up MailPit service...";
# Create log and service config files for MailPit
rm -f /etc/systemd/system/mailpit.service;
touch /etc/systemd/system/mailpit.service;
touch /var/log/mailpit.log;

# Create a directory and database file for MailPit
mkdir -p /var/lib/mailpit && touch /var/lib/mailpit/mailpit.db

# Push content into the MailPit service config file
echo "[Unit]
Description=Mailpit server
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/mailpit -d /var/lib/mailpit/mailpit.db
Restart=always
# Restart service after 10 seconds service crashes
RestartSec=10
SyslogIdentifier=mailpit
StandardOutput=file:/var/log/mailpit.log
StandardError=file:/var/log/mailpit.log

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/mailpit.service;

# Set permissions for the MailPit service config file
chmod 664 /etc/systemd/system/mailpit.service;

# Reload the systemd manager configuration
systemctl daemon-reload && systemctl enable mailpit.service

# Start the MailPit service and check its status
systemctl start mailpit.service -v && systemctl status mailpit.service;

# Other method to run MailPit Server directly from CLI and log its output
# /bin/bash nohup /usr/local/bin/mailpit -d /var/lib/mailpit/mailpit.db > ~/mailpit.log 2>&1 &
