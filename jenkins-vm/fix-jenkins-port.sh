#!/bin/bash
set -e

echo "Configuring Jenkins to run on port 80..."

# Stop Jenkins
systemctl stop jenkins || true

# Create Jenkins directory on data disk
MOUNT_POINT="/jenkins"
mkdir -p "$MOUNT_POINT/jenkins_home"
chown -R jenkins:jenkins "$MOUNT_POINT/jenkins_home"

# Update Jenkins configuration 
sed -i 's|JENKINS_HOME="/var/lib/jenkins"|JENKINS_HOME="'"$MOUNT_POINT"'/jenkins_home"|' /usr/lib/systemd/system/jenkins.service

# Configure Jenkins to run on port 80
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf <<-'CONF'
[Service]
Environment="JENKINS_PORT=80"
# Allow binding to privileged ports
AmbientCapabilities=CAP_NET_BIND_SERVICE
CONF

# Give Java permission to bind to privileged ports
JAVA_PATH=$(readlink -f /usr/bin/java)
setcap 'cap_net_bind_service=+ep' "$JAVA_PATH"

# Reload systemd and start Jenkins
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Open firewall for Jenkins
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

# Wait for Jenkins to start
sleep 10

echo "Jenkins installation completed!"
echo "Jenkins is running on port 80"
echo  ""
if [ -f "$MOUNT_POINT/jenkins_home/secrets/initialAdminPassword" ]; then
  echo "Initial admin password: $(cat $MOUNT_POINT/jenkins_home/secrets/initialAdminPassword)"
else
  echo "Initial password not yet generated. Wait a minute and check: sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword"
fi
