# Windows Test Server

This Terraform configuration creates a Windows Server 2022 VM in the same VPC and subnet as Jenkins for testing the Internal HTTPS Load Balancer.

## Components

### 1. Windows Server VM
- **Name**: `windows-test-server`
- **OS**: Windows Server 2022 Datacenter
- **Machine Type**: e2-standard-2 (2 vCPUs, 8 GB RAM)
- **Network**: vpc-spoke
- **Subnet**: subnet-jenkins
- **Access**: Via IAP (no external IP)

### 2. Firewall Rules
- **RDP Access**: Port 3389 via IAP (35.235.240.0/20)
- **Internal Traffic**: Ports 80, 443, 445, 139 and ICMP from subnet (10.10.0.0/16)

## Deployment

1. Initialize Terraform:
   ```bash
   cd windows-test-vm
   terraform init
   ```

2. Review the planned changes:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

## Accessing the Windows Server

### Step 1: Reset Windows Password

```bash
gcloud compute reset-windows-password windows-test-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --user=admin
```

Save the username and password provided.

### Step 2: Connect via RDP using IAP Tunnel

```bash
# Start IAP tunnel for RDP
gcloud compute start-iap-tunnel windows-test-server 3389 \
  --local-host-port=localhost:3389 \
  --zone=us-central1-a \
  --project=core-it-infra-prod
```

### Step 3: Connect with Remote Desktop

1. Open **Remote Desktop Connection** (mstsc.exe on Windows)
2. Connect to: `localhost:3389`
3. Enter the username and password from Step 1

## Testing Jenkins Access

Once connected to the Windows Server:

### Option 1: Using PowerShell

```powershell
# Test DNS resolution
nslookup jenkins.np.learningmyway.space

# Test connectivity (will show SSL error without CA cert)
curl https://jenkins.np.learningmyway.space

# Test with SSL verification bypass
curl -k https://jenkins.np.learningmyway.space
```

### Option 2: Using Browser

1. Open **Microsoft Edge** or **Chrome**
2. Navigate to: `https://jenkins.np.learningmyway.space`
3. You'll see a certificate warning (because CA is not trusted)
4. Click "Advanced" → "Proceed to jenkins.np.learningmyway.space"
5. You should see the Jenkins login page

### Option 3: Install CA Certificates (Proper Solution)

1. **Copy CA certificates to Windows Server**:
   ```bash
   # From your local machine
   gcloud compute scp c:\Users\ab45706\gcp-learning-hub\cert\root-ca.crt windows-test-server:C:\temp\ --zone=us-central1-a --project=core-it-infra-prod
   ```

2. **Install CA certificate on Windows**:
   - Double-click the certificate file
   - Click "Install Certificate"
   - Select "Local Machine"
   - Choose "Place all certificates in the following store"
   - Browse and select "Trusted Root Certification Authorities"
   - Complete the wizard

3. **Test again**:
   - Open browser and navigate to `https://jenkins.np.learningmyway.space`
   - No certificate warning should appear

## Verification

Test that everything works:

```powershell
# Test DNS
Resolve-DnsName jenkins.np.learningmyway.space

# Test connectivity
Test-NetConnection -ComputerName 10.10.10.50 -Port 443

# Test HTTPS (PowerShell)
Invoke-WebRequest -Uri https://jenkins.np.learningmyway.space -UseBasicParsing
```

## Architecture

```
Windows Test Server (10.10.x.x)
     ↓ DNS Query
Cloud DNS → jenkins.np.learningmyway.space = 10.10.10.50
     ↓ HTTPS Request
Internal Load Balancer (10.10.10.50:443)
     ↓ HTTP
Jenkins Server (port 80)
```

## Network Details

- **VPC**: vpc-spoke
- **Subnet**: subnet-jenkins (10.10.0.0/16)
- **No external IP**: Access via IAP only
- **Same subnet as Jenkins**: Can reach load balancer directly

## Cleanup

To remove the Windows Server:

```bash
cd windows-test-vm
terraform destroy
```

## Cost Note

Windows Server instances incur licensing costs. Remember to destroy the VM when testing is complete to avoid unnecessary charges.
