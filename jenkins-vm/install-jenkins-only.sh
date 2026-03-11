#!/bin/bash
set -e

echo "Installing wget..."
dnf install -y wget

echo "Installing Jenkins..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins

echo "Configuring Jenkins..."
systemctl stop jenkins || true

# Create Jenkins directory on data disk
MOUNT_POINT="/jenkins"
mkdir -p "$MOUNT_POINT/jenkins_home"
chown -R jenkins:jenkins "$MOUNT_POINT/jenkins_home"

# Update Jenkins configuration
sed -i 's|JENKINS_HOME="/var/lib/jenkins"|JENKINS_HOME="'"$MOUNT_POINT"'/jenkins_home"|' /usr/lib/systemd/system/jenkins.service

# Configure Jenkins to run on port 80
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf <<-CONF
[Service]
Environment="JENKINS_PORT=80"
CONF

# Reload systemd and start Jenkins
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Open firewall for Jenkins
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

echo "Jenkins installation completed!"
echo "Jenkins is running on port 80"
echo "Initial admin password: $(cat $MOUNT_POINT/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo 'Password not yet generated, wait a moment')"
