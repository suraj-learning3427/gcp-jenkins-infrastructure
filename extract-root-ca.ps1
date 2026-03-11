# PowerShell script to extract Root CA from fullchain.pem

$fullchain = Get-Content .\cert\fullchain.pem -Raw

# Split by certificate boundaries
$certs = $fullchain -split '(?=-----BEGIN CERTIFICATE-----)'

Write-Host "Found $($certs.Count) certificates in fullchain.pem"

# The last certificate in the chain should be closest to root
# In your case: [0] = Jenkins cert, [1] = Intermediate cert
# We need the issuer of intermediate, which is the Root CA

# Extract the intermediate certificate (second one)
$intermediateCert = $certs[1].Trim()

Write-Host "`nIntermediate Certificate:`n$intermediateCert"

# Note: The actual Root CA certificate is NOT in fullchain.pem
# You need to get it from where you originally created the certificates
Write-Host "`n`nWARNING: Root CA certificate is NOT in fullchain.pem!"
Write-Host "You need the original rootCA.crt file that was used to sign the intermediate certificate."
Write-Host "`nCheck these locations:"
Write-Host "  - Where you originally generated the certificates"
Write-Host "  - Your Downloads folder"
Write-Host "  - Any backup or certificate generation directory"
