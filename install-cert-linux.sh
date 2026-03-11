#!/bin/bash
# Script to install root CA certificate on Linux (Rocky Linux, RHEL, CentOS)

echo "Installing CA certificate..."

# Copy certificate to trusted anchors
sudo cp cert/rootCA.crt /etc/pki/ca-trust/source/anchors/jenkins-rootca.crt

# Update CA trust
sudo update-ca-trust extract

echo "Certificate installed successfully!"
echo "You can now access Jenkins without certificate warnings."
