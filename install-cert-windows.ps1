# Script to install root CA certificate on Windows
# Run as Administrator

$certPath = ".\cert\rootCA.crt"

# Import certificate to Trusted Root Certification Authorities
Write-Host "Installing certificate to Trusted Root Certification Authorities..."
Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root

Write-Host "Certificate installed successfully!"
Write-Host "Restart your browser to apply changes."
