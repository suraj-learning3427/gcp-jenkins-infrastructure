#!/bin/bash
set -e

echo "Configuring Jenkins on port 8080 with port 80 redirect..."

# Stop Jenkins
systemctl stop jenkins || true

# Create Jenkins directory on data disk  
MOUNT_POINT="/jenkins"
mkdir -p "$MOUNT_POINT/jenkins_home"
chown -R jenkins:jenkins "$MOUNT_POINT/jenkins_home"

# Update Jenkins home directory
sed -i 's|JENKINS_HOME="/var/lib/jenkins"|JENKINS_HOME="'"$MOUNT_POINT"'/jenkins_home"|' /usr/lib/systemd/system/jenkins.service

# Remove the port 80 override
rm -rf /etc/systemd/system/jenkins.service.d/

# Reload systemd and start Jenkins (on port 8080)
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
sleep 15

# Configure firewall - allow both ports
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

# Redirect port 80 to 8080 using iptables
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

# Make iptables rule persistent across reboots
dnf install -y iptables-services
systemctl enable iptables
iptables-save > /etc/sysconfig/iptables

echo "Jenkins installation completed!"
echo "Jenkins is running on port 8080, accessible via port 80"
echo ""
if [ -f "$MOUNT_POINT/jenkins_home/secrets/initialAdminPassword" ]; then
  echo "Initial admin password: $(cat $MOUNT_POINT/jenkins_home/secrets/initialAdminPassword)"
else
  echo "Initial password not yet generated. Wait a minute and run: sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword"
fi
