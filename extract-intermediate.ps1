# Extract intermediate certificate from fullchain.pem
$fullchain = Get-Content .\cert\fullchain.pem -Raw

# Split certificates
$certStart = "-----BEGIN CERTIFICATE-----"
$certEnd = "-----END CERTIFICATE-----"

# Find all certificate boundaries
$matches = [regex]::Matches($fullchain, "(?s)$certStart.*?$certEnd")

if ($matches.Count -ge 2) {
    # Second certificate is the intermediate
    $intermediateCert = $matches[1].Value
    
    # Save to file
    $intermediateCert | Out-File -FilePath ".\cert\intermediate-extracted.crt" -Encoding ASCII
    
    Write-Host "Intermediate certificate extracted to: .\cert\intermediate-extracted.crt"
    Write-Host ""
    Write-Host "Now copy this file to your personal laptop and install it with:"
    Write-Host "Import-Certificate -FilePath 'C:\path\to\intermediate-extracted.crt' -CertStoreLocation Cert:\LocalMachine\CA"
} else {
    Write-Host "ERROR: Could not find intermediate certificate in fullchain.pem"
    Write-Host "Found $($matches.Count) certificates, expected at least 2"
}
