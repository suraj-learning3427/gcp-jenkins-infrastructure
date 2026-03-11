#!/bin/bash
set -e

# Log all output
exec > >(tee -a /var/log/jenkins-install.log)
exec 2>&1

echo "Starting VM setup..."

# Wait for the data disk to be available
while [ ! -e /dev/disk/by-id/google-jenkins-data ]; do
  echo "Waiting for data disk..."
  sleep 2
done

# Format and mount the data disk
DISK_DEVICE="/dev/disk/by-id/google-jenkins-data"
MOUNT_POINT="/jenkins"

# Check if the disk is already formatted
if ! blkid "$DISK_DEVICE"; then
  echo "Formatting data disk..."
  mkfs.ext4 -F "$DISK_DEVICE"
fi

# Create mount point
mkdir -p "$MOUNT_POINT"

# Mount the disk
mount "$DISK_DEVICE" "$MOUNT_POINT"

# Add to fstab for persistent mounting
UUID=$(blkid -s UUID -o value "$DISK_DEVICE")
if ! grep -q "$UUID" /etc/fstab; then
  echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
fi

echo "Data disk mounted at $MOUNT_POINT"

# Update system
echo "Updating system packages..."
dnf update -y

# Install Java and wget (required for Jenkins)
echo "Installing Java and wget..."
dnf install -y java-17-openjdk java-17-openjdk-devel wget

# Install Jenkins
echo "Installing Jenkins..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins

# Configure Jenkins to use the data disk
echo "Configuring Jenkins..."
systemctl stop jenkins || true

# Create Jenkins directory on data disk
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
echo "Initial admin password location: $MOUNT_POINT/jenkins_home/secrets/initialAdminPassword"
