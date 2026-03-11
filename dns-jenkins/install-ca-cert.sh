#!/bin/bash
# Script to install custom CA certificates on Rocky Linux/RHEL

set -e

echo "Installing custom CA certificates..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Create directory for custom CA certificates if it doesn't exist
CA_CERT_DIR="/etc/pki/ca-trust/source/anchors"
mkdir -p "$CA_CERT_DIR"

echo "Place your CA certificates (root and intermediate) in: $CA_CERT_DIR"
echo "Certificate files should have .crt or .pem extension"
echo ""
echo "Example:"
echo "  sudo cp /path/to/root-ca.crt $CA_CERT_DIR/"
echo "  sudo cp /path/to/intermediate-ca.crt $CA_CERT_DIR/"
echo ""
echo "After copying the certificates, run:"
echo "  sudo update-ca-trust extract"
echo ""
echo "Then test with:"
echo "  curl https://jenkins.np.learningmyway.space"

# If certificates are provided as arguments, copy them
if [ $# -gt 0 ]; then
    for cert in "$@"; do
        if [ -f "$cert" ]; then
            echo "Copying $cert to $CA_CERT_DIR/"
            cp "$cert" "$CA_CERT_DIR/"
        else
            echo "Warning: $cert not found, skipping"
        fi
    done
    
    echo "Updating CA trust store..."
    update-ca-trust extract
    
    echo "CA certificates installed successfully!"
    echo "Testing connection..."
    curl -I https://jenkins.np.learningmyway.space || echo "Connection test failed"
fi
