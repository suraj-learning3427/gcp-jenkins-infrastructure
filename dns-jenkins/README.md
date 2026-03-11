# Jenkins Private DNS Configuration

This Terraform configuration creates a private Cloud DNS zone for internal Jenkins access via hostname instead of IP address.

## Components

### 1. Private DNS Zone
- **Name**: `jenkins-private-zone`
- **Domain**: `learningmyway.space`
- **Visibility**: Private (accessible only from VPC)
- **Network**: `vpc-spoke`

### 2. DNS Records
- **A Record**: `jenkins.np.learningmyway.space` → `10.10.10.50`
- **CNAME Record**: `www.jenkins.np.learningmyway.space` → `jenkins.np.learningmyway.space`

## Prerequisites

1. VPC `vpc-spoke` must exist
2. Jenkins Internal Load Balancer must be deployed with IP `10.10.10.50`
3. Cloud DNS API must be enabled in the project

## Deployment

1. Initialize Terraform:
   ```bash
   cd dns-jenkins
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

## Usage

After deployment, you can access Jenkins using the hostname:

```bash
# From any VM in the VPC or peered networks
curl https://jenkins.np.learningmyway.space

# Or in a browser
https://jenkins.np.learningmyway.space
```

## DNS Resolution

The private DNS zone is automatically used by:
- All VMs in the `vpc-spoke` network
- VMs in peered networks (if DNS peering is configured)
- Resources using the VPC's DNS resolver

## Verification

Test DNS resolution from a VM in the VPC:

```bash
# SSH to any VM in vpc-spoke (e.g., jenkins-server)
gcloud compute ssh jenkins-server --project core-it-infra-prod --zone us-central1-a --tunnel-through-iap

# Test DNS resolution
nslookup jenkins.np.learningmyway.space
dig jenkins.np.learningmyway.space

# Test HTTPS access
curl https://jenkins.np.learningmyway.space
```

Expected DNS response:
```
jenkins.np.learningmyway.space. 300 IN A 10.10.10.50
```

## Architecture

```
VMs in vpc-spoke
     ↓ (DNS Query)
Cloud DNS Private Zone (learningmyway.space)
     ↓ (Returns)
jenkins.np.learningmyway.space → 10.10.10.50
     ↓ (HTTPS Request)
Internal Load Balancer (10.10.10.50:443)
     ↓
Jenkins Server
```

## Notes

- This is a **Private DNS Zone** - only accessible from within the VPC
- DNS records have a TTL of 300 seconds (5 minutes)
- The SSL certificate should match the hostname `jenkins.np.learningmyway.space`
- If accessing from peered networks, ensure DNS peering is enabled

## Troubleshooting

If DNS is not resolving:

1. **Check DNS API is enabled**:
   ```bash
   gcloud services enable dns.googleapis.com --project=core-it-infra-prod
   ```

2. **Verify DNS zone visibility**:
   - Ensure the zone is associated with the correct VPC
   - Check that the VM is in the `vpc-spoke` network

3. **Test from Jenkins server**:
   ```bash
   # Clear DNS cache (if applicable)
   sudo systemd-resolve --flush-caches
   
   # Test resolution
   dig jenkins.np.learningmyway.space
   ```

4. **Check firewall rules**:
   - Ensure DNS traffic (UDP/53) is not blocked
