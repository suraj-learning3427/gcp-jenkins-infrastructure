# GCP Jenkins Infrastructure POC - Complete Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Prerequisites](#prerequisites)
5. [Deployment Guide](#deployment-guide)
6. [Access and Testing](#access-and-testing)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [Maintenance and Operations](#maintenance-and-operations)
9. [Cleanup](#cleanup)

---

## Project Overview

This POC demonstrates a secure, production-ready Jenkins infrastructure on Google Cloud Platform (GCP) using Terraform Infrastructure as Code (IaC). The solution implements a hub-and-spoke network architecture with internal HTTPS load balancing, private DNS resolution, and secure access controls.

### Key Features
- ✅ **Secure Internal Access**: Jenkins accessible only via internal network (no external IP)
- ✅ **HTTPS Encryption**: SSL/TLS certificates for secure communication
- ✅ **Internal Load Balancing**: Regional Internal HTTPS Load Balancer
- ✅ **Private DNS**: Custom private DNS zone for hostname-based access
- ✅ **Hub-Spoke Network**: Scalable network architecture with VPC peering
- ✅ **IAP Access**: Identity-Aware Proxy for secure SSH/RDP access
- ✅ **VPN Gateway**: Optional Firezone gateway for external secure access
- ✅ **Infrastructure as Code**: Complete Terraform automation

### Projects Structure
- **networkingglobal-prod**: Hub VPC with VPN gateway
- **core-it-infra-prod**: Spoke VPC with Jenkins infrastructure

---

## Architecture

### Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    networkingglobal-prod                         │
│                         (Hub VPC)                                │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  vpc-hub (20.20.0.0/16)                                     │ │
│  │  ├── subnet-vpn (20.20.0.0/16, us-central1)                │ │
│  │  ├── Firezone Gateway (VPN for remote access)              │ │
│  │  └── Firewall: WireGuard (UDP:51820), IAP SSH              │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              |
                         VPC Peering
                              |
┌─────────────────────────────────────────────────────────────────┐
│                    core-it-infra-prod                            │
│                        (Spoke VPC)                               │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  vpc-spoke (10.10.0.0/16)                                   │ │
│  │  ├── subnet-jenkins (10.10.0.0/16, us-central1)            │ │
│  │  ├── proxy-only subnet (10.129.0.0/23) - for ILB           │ │
│  │  │                                                           │ │
│  │  ├── Jenkins Server VM (Rocky Linux 9)                     │ │
│  │  │   - Internal IP: 10.10.x.x                              │ │
│  │  │   - Jenkins on port 8080                                │ │
│  │  │   - Data disk: /jenkins (20 GB)                         │ │
│  │  │                                                           │ │
│  │  ├── Internal HTTPS Load Balancer                          │ │
│  │  │   - Static IP: 10.10.10.50                              │ │
│  │  │   - HTTPS (443) → HTTP (8080)                           │ │
│  │  │   - Health check: /login endpoint                       │ │
│  │  │                                                           │ │
│  │  ├── Private DNS Zone                                       │ │
│  │  │   - Domain: learningmyway.space                         │ │
│  │  │   - A Record: jenkins.np.learningmyway.space            │  │
│  │  │   - Points to: 10.10.10.50 (ILB IP)                     │ │
│  │  │                                                           │ │
│  │  └── Windows Test Server (Optional)                        │ │
│  │      - For testing DNS and HTTPS access                    │ │
│  │      - Same subnet as Jenkins                              │ │
│  │      - RDP access via IAP                                  │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Traffic Flow

```
External User
    ↓
VPN Gateway (Firezone) - Optional
    ↓
vpc-hub (20.20.0.0/16)
    ↓
VPC Peering
    ↓
vpc-spoke (10.10.0.0/16)
    ↓
DNS Resolution: jenkins.np.learningmyway.space → 10.10.10.50
    ↓
Internal HTTPS Load Balancer (10.10.10.50:443)
    ↓
SSL Termination
    ↓
Backend Service (HTTP)
    ↓
Health Check (/login on port 8080)
    ↓
Jenkins Instance Group
    ↓
Jenkins Server (port 8080)
```

---

## Components

### 1. Networkingglobal (Hub VPC)

**Location**: `Networkingglobal/`

**Resources**:
- VPC: `vpc-hub`
- Subnet: `subnet-vpn` (20.20.0.0/16) in us-central1
- Firewall rules:
  - IAP SSH access (TCP:22 from 35.235.240.0/20)
  - WireGuard VPN (UDP:51820)

**Purpose**: Central hub for VPN connectivity and network peering

### 2. Core IT Infrastructure (Spoke VPC)

**Location**: `core-it-infrastructure/`

**Resources**:
- Project: `core-it-infra-prod`
- VPC: `vpc-spoke`
- Subnet: `subnet-jenkins` (10.10.0.0/16) in us-central1
- Firewall rules:
  - IAP SSH access (TCP:22)
  - Hub traffic (TCP:443 from 20.20.0.0/16)

**Purpose**: Host Jenkins and application infrastructure

### 3. Jenkins Virtual Machine

**Location**: `jenkins-vm/`

**Specifications**:
- Name: `jenkins-server`
- OS: Rocky Linux 9
- Machine Type: e2-standard-2 (2 vCPUs, 8 GB RAM)
- Zone: us-central1-a
- Disks:
  - Boot disk: 20 GB (pd-standard)
  - Data disk: 20 GB (pd-standard, mounted at `/jenkins`)
- Network: No external IP (IAP access only)

**Jenkins Configuration**:
- Jenkins Home: `/jenkins/jenkins_home` (on data disk)
- Service Port: 8080 (internal)
- Port 80 redirects to port 8080 via iptables
- Auto-start on boot
- Startup logs: `/var/log/startup-script.log`

**Scripts Provided**:
- `install-jenkins.sh`: Initial Jenkins installation
- `install-jenkins-only.sh`: Jenkins package installation only
- `install-jenkins-complete.sh`: Full automated setup
- `setup-jenkins-final.sh`: Configure Jenkins with proper ports and data disk
- `fix-jenkins-port.sh`: Fix port configuration issues

### 4. Internal HTTPS Load Balancer

**Location**: `jenkins-ilb/`

**Components**:

**Instance Group**:
- Name: `jenkins-instance-group`
- Zone: us-central1-a
- Members: `jenkins-server`
- Named ports: http:8080, http-alt:80

**Health Check**:
- Protocol: HTTP
- Port: 8080
- Path: `/login`
- Check interval: 10 seconds
- Timeout: 5 seconds

**Backend Service**:
- Type: Regional Backend Service
- Protocol: HTTP (internal)
- Load balancing scheme: INTERNAL_MANAGED

**SSL Certificate**:
- Type: Regional self-signed certificate
- Private key: `../cert/jenkins.key`
- Certificate chain: `../cert/fullchain.pem`

**Forwarding Rule**:
- Static IP: 10.10.10.50 (reserved)
- Protocol: HTTPS
- Port: 443
- Region: us-central1

**Important**: Requires proxy-only subnet (10.129.0.0/23) for GCP's internal load balancers

### 5. Private DNS Configuration

**Location**: `dns-jenkins/`

**DNS Zone**:
- Name: `jenkins-private-zone`
- Domain: `learningmyway.space`
- Visibility: Private (vpc-spoke only)

**DNS Records**:
- A Record: `jenkins.np.learningmyway.space` → `10.10.10.50`
- CNAME Record: `www.jenkins.np.learningmyway.space` → `jenkins.np.learningmyway.space`
- TTL: 300 seconds (5 minutes)

**Purpose**: Enable hostname-based access instead of IP addresses

### 6. Firezone VPN Gateway (Optional)

**Location**: `terraform-google-gateway/`

**Purpose**: Provide secure external access to internal resources

**Configuration**:
- Project: networkingglobal-prod
- VPC: vpc-hub
- Subnet: subnet-vpn
- Region: us-central1

### 7. Windows Test Server (Optional)

**Location**: `windows-test-vm/`

**Specifications**:
- Name: `windows-test-server`
- OS: Windows Server 2022 Datacenter
- Machine Type: e2-standard-2
- Network: Same as Jenkins (vpc-spoke, subnet-jenkins)
- Access: RDP via IAP tunnel

**Purpose**: Test DNS resolution and HTTPS access to Jenkins from Windows environment

---

## Prerequisites

### 1. GCP Account and Permissions

Required IAM permissions:
- Compute Admin
- Network Admin
- DNS Administrator
- Service Account Admin
- Project Creator (for new projects)

### 2. Local Environment Setup

**Required Tools**:
```bash
# Install gcloud CLI
# Visit: https://cloud.google.com/sdk/docs/install

# Install Terraform
# Visit: https://developer.hashicorp.com/terraform/downloads

# Verify installations
gcloud --version
terraform --version
```

**Authenticate with GCP**:
```bash
gcloud auth login
gcloud auth application-default login
```

**Set Default Project**:
```bash
gcloud config set project core-it-infra-prod
```

### 3. GCP APIs to Enable

Enable required APIs in both projects:

```bash
# For networkingglobal-prod
gcloud services enable compute.googleapis.com --project=networkingglobal-prod
gcloud services enable servicenetworking.googleapis.com --project=networkingglobal-prod

# For core-it-infra-prod
gcloud services enable compute.googleapis.com --project=core-it-infra-prod
gcloud services enable dns.googleapis.com --project=core-it-infra-prod
gcloud services enable servicenetworking.googleapis.com --project=core-it-infra-prod
gcloud services enable iap.googleapis.com --project=core-it-infra-prod
```

### 4. SSL Certificates

Generate self-signed certificates for testing:

```bash
# Create cert directory
mkdir -p cert
cd cert

# Generate private key
openssl genrsa -out jenkins.key 2048

# Generate certificate (valid for 365 days)
openssl req -new -x509 -key jenkins.key -out fullchain.pem -days 365 \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=jenkins.np.learningmyway.space"

# Generate root CA (for client trust)
openssl req -new -x509 -key jenkins.key -out root-ca.crt -days 365 \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=Root CA"

cd ..
```

**Production Note**: For production, use certificates from a trusted CA or Google-managed certificates.

### 5. Network Prerequisites

Before deploying Jenkins infrastructure:
- Hub VPC (vpc-hub) must exist
- Spoke VPC (vpc-spoke) must exist
- VPC peering must be configured between hub and spoke
- Subnet for Jenkins must exist
- Proxy-only subnet for ILB must be configured

---

## Deployment Guide

### Deployment Order

Deploy components in this specific order due to dependencies:

1. **Networkingglobal** (Hub VPC) → 2. **Core IT Infrastructure** (Spoke VPC) → 3. **Jenkins VM** → 4. **Jenkins Internal Load Balancer** → 5. **DNS Configuration** → 6. **Optional: Windows Test VM**

### Step 1: Deploy Network Infrastructure (Hub VPC)

```bash
cd Networkingglobal

# Review and update terraform.tfvars
# Set your project ID and configuration

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply -auto-approve

# Note the outputs
terraform output
```

**Verify**:
```bash
gcloud compute networks list --project=networkingglobal-prod
gcloud compute networks subnets list --network=vpc-hub --project=networkingglobal-prod
```

### Step 2: Deploy Core IT Infrastructure (Spoke VPC)

```bash
cd ../core-it-infrastructure

# Review and update terraform.tfvars
# Ensure project_id = "core-it-infra-prod"

terraform init
terraform plan
terraform apply -auto-approve

terraform output
```

**Verify**:
```bash
gcloud compute networks list --project=core-it-infra-prod
gcloud compute networks subnets list --network=vpc-spoke --project=core-it-infra-prod
gcloud compute firewall-rules list --project=core-it-infra-prod
```

### Step 3: Configure VPC Peering (If Not Already Done)

```bash
# Create peering from spoke to hub
gcloud compute networks peerings create spoke-to-hub \
  --network=vpc-spoke \
  --peer-network=vpc-hub \
  --peer-project=networkingglobal-prod \
  --project=core-it-infra-prod

# Create peering from hub to spoke
gcloud compute networks peerings create hub-to-spoke \
  --network=vpc-hub \
  --peer-network=vpc-spoke \
  --peer-project=core-it-infra-prod \
  --project=networkingglobal-prod
```

**Verify Peering**:
```bash
gcloud compute networks peerings list --network=vpc-spoke --project=core-it-infra-prod
```

### Step 4: Create Proxy-Only Subnet for ILB

```bash
gcloud compute networks subnets create proxy-only-subnet \
  --purpose=REGIONAL_MANAGED_PROXY \
  --role=ACTIVE \
  --region=us-central1 \
  --network=vpc-spoke \
  --range=10.129.0.0/23 \
  --project=core-it-infra-prod
```

**Verify**:
```bash
gcloud compute networks subnets describe proxy-only-subnet \
  --region=us-central1 \
  --project=core-it-infra-prod
```

### Step 5: Deploy Jenkins VM

```bash
cd ../jenkins-vm

# Review terraform.tfvars
# Verify project_id, region, zone, and other settings

terraform init
terraform plan
terraform apply -auto-approve

# Save outputs
terraform output jenkins_vm_internal_ip
terraform output jenkins_vm_name
```

**Wait for Jenkins Installation** (approximately 5-10 minutes):
```bash
# Monitor startup script
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo tail -f /var/log/startup-script.log'
```

**Verify Jenkins Service**:
```bash
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo systemctl status jenkins'
```

**Get Initial Admin Password**:
```bash
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword'
```

### Step 6: Configure Firewall for Load Balancer

```bash
# Allow health checks and traffic from proxy subnet to Jenkins
gcloud compute firewall-rules create allow-ilb-to-jenkins \
  --network=vpc-spoke \
  --action=allow \
  --direction=ingress \
  --source-ranges=10.129.0.0/23,35.191.0.0/16,130.211.0.0/22 \
  --target-tags=jenkins-server \
  --rules=tcp:8080,tcp:80 \
  --project=core-it-infra-prod
```

### Step 7: Deploy Internal HTTPS Load Balancer

```bash
cd ../jenkins-ilb

# Ensure SSL certificates exist in ../cert/
ls -la ../cert/jenkins.key
ls -la ../cert/fullchain.pem

# Review terraform.tfvars
terraform init
terraform plan
terraform apply -auto-approve

# Save load balancer IP
terraform output load_balancer_ip
```

**Verify Load Balancer**:
```bash
# Check forwarding rule
gcloud compute forwarding-rules describe jenkins-forwarding-rule \
  --region=us-central1 \
  --project=core-it-infra-prod

# Check backend service health
gcloud compute backend-services get-health jenkins-backend-service \
  --region=us-central1 \
  --project=core-it-infra-prod
```

### Step 8: Deploy Private DNS

```bash
cd ../dns-jenkins

# Review terraform.tfvars
# Ensure DNS record points to ILB IP (10.10.10.50)

terraform init
terraform plan
terraform apply -auto-approve

terraform output
```

**Verify DNS**:
```bash
# Test from Jenkins server
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='nslookup jenkins.np.learningmyway.space'
```

Expected output:
```
Server:    169.254.169.254
Address:   169.254.169.254#53

Name:   jenkins.np.learningmyway.space
Address: 10.10.10.50
```

### Step 9: Deploy Windows Test VM (Optional)

```bash
cd ../windows-test-vm

terraform init
terraform plan
terraform apply -auto-approve
```

---

## Access and Testing

### Access Jenkins via SSH Tunnel

**Method 1: Direct Port Forwarding**

```bash
# Forward port 8080 from Jenkins VM to local machine
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  -- -L 8080:localhost:8080
```

Then open browser: `http://localhost:8080`

**Method 2: Access via Load Balancer IP**

From a VM within the VPC:
```bash
# Test with curl
curl -k https://10.10.10.50

# Test DNS resolution
curl -k https://jenkins.np.learningmyway.space
```

### Test DNS Resolution

**From Jenkins Server**:
```bash
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='dig jenkins.np.learningmyway.space'
```

**Expected Output**:
```
jenkins.np.learningmyway.space. 300 IN A 10.10.10.50
```

### Test from Windows Server

1. **Reset Windows Password**:
```bash
gcloud compute reset-windows-password windows-test-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --user=admin
```

2. **Create RDP Tunnel**:
```bash
gcloud compute start-iap-tunnel windows-test-server 3389 \
  --local-host-port=localhost:3389 \
  --zone=us-central1-a \
  --project=core-it-infra-prod
```

3. **Connect via RDP**: Open Remote Desktop Connection to `localhost:3389`

4. **Test from PowerShell**:
```powershell
# Test DNS
Resolve-DnsName jenkins.np.learningmyway.space

# Test connectivity
Test-NetConnection -ComputerName 10.10.10.50 -Port 443

# Test HTTPS (ignore certificate warning)
Invoke-WebRequest -Uri https://jenkins.np.learningmyway.space -UseBasicParsing
```

5. **Open Browser**: Navigate to `https://jenkins.np.learningmyway.space`

### Install CA Certificates (Optional)

**On Rocky Linux (Jenkins Server)**:
```bash
# SSH to Jenkins server
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap

# Copy CA certificate (from local machine)
# Use gcloud compute scp to upload root-ca.crt

# Install CA certificate
sudo cp root-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract

# Test
curl https://jenkins.np.learningmyway.space
```

**On Windows Server**:
1. Copy `root-ca.crt` to Windows server using gcloud scp
2. Double-click certificate file
3. Install to "Trusted Root Certification Authorities"
4. Browser will now trust the certificate

---

## Troubleshooting Guide

### 1. Jenkins VM Issues

#### Issue: Jenkins Service Not Starting

**Symptoms**:
- Service fails to start
- Port 8080 not responding

**Diagnosis**:
```bash
# Check service status
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo systemctl status jenkins'

# Check startup logs
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo tail -100 /var/log/startup-script.log'

# Check Jenkins logs
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo journalctl -u jenkins -n 100'
```

**Solutions**:

**A. Java Not Installed**:
```bash
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo dnf install -y java-17-openjdk java-17-openjdk-devel'
```

**B. Permissions Issue on Data Disk**:
```bash
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo chown -R jenkins:jenkins /jenkins/jenkins_home'
```

**C. Data Disk Not Mounted**:
```bash
# Check mount
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='df -h | grep /jenkins'

# If not mounted, remount
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo mount /dev/sdb /jenkins'
```

**D. Port Configuration Issue**:
```bash
# Re-run setup script
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap

# On the server:
sudo bash /path/to/setup-jenkins-final.sh
```

**E. Restart Jenkins**:
```bash
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo systemctl restart jenkins'
```

#### Issue: Cannot SSH to Jenkins Server

**Symptoms**:
- IAP tunnel fails
- Connection timeout

**Diagnosis**:
```bash
# Check VM is running
gcloud compute instances describe jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod

# Check firewall rules
gcloud compute firewall-rules list \
  --filter="name~iap" \
  --project=core-it-infra-prod

# Check IAP is enabled
gcloud services list --enabled --project=core-it-infra-prod | grep iap
```

**Solutions**:

**A. Enable IAP API**:
```bash
gcloud services enable iap.googleapis.com --project=core-it-infra-prod
```

**B. Create/Fix IAP Firewall Rule**:
```bash
gcloud compute firewall-rules create allow-iap-ssh \
  --network=vpc-spoke \
  --action=allow \
  --direction=ingress \
  --source-ranges=35.235.240.0/20 \
  --rules=tcp:22 \
  --project=core-it-infra-prod
```

**C. Check VM Status**:
```bash
# If VM is stopped, start it
gcloud compute instances start jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod
```

### 2. Load Balancer Issues

#### Issue: Load Balancer Shows Unhealthy

**Symptoms**:
- Backend service health check fails
- Cannot access Jenkins via load balancer

**Diagnosis**:
```bash
# Check backend health
gcloud compute backend-services get-health jenkins-backend-service \
  --region=us-central1 \
  --project=core-it-infra-prod

# Check health check configuration
gcloud compute health-checks describe jenkins-health-check \
  --region=us-central1 \
  --project=core-it-infra-prod

# Check forwarding rule
gcloud compute forwarding-rules describe jenkins-forwarding-rule \
  --region=us-central1 \
  --project=core-it-infra-prod
```

**Solutions**:

**A. Firewall Not Allowing Health Checks**:
```bash
# Health checks come from these ranges:
# 35.191.0.0/16 and 130.211.0.0/22
gcloud compute firewall-rules create allow-health-checks \
  --network=vpc-spoke \
  --action=allow \
  --direction=ingress \
  --source-ranges=35.191.0.0/16,130.211.0.0/22 \
  --target-tags=jenkins-server \
  --rules=tcp:8080 \
  --project=core-it-infra-prod
```

**B. Firewall Not Allowing Proxy Subnet**:
```bash
gcloud compute firewall-rules create allow-proxy-to-jenkins \
  --network=vpc-spoke \
  --action=allow \
  --direction=ingress \
  --source-ranges=10.129.0.0/23 \
  --target-tags=jenkins-server \
  --rules=tcp:8080,tcp:80 \
  --project=core-it-infra-prod
```

**C. Jenkins Not Responding on Port 8080**:
```bash
# From Jenkins server
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='curl http://localhost:8080/login'

# If not responding, check Jenkins
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo systemctl status jenkins'
```

**D. Wrong Health Check Path**:
```bash
# Health check is configured for /login
# Ensure Jenkins /login page is accessible
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='curl -I http://localhost:8080/login'
```

**E. Missing Proxy-Only Subnet**:
```bash
# Verify proxy-only subnet exists
gcloud compute networks subnets list \
  --filter="purpose=REGIONAL_MANAGED_PROXY" \
  --project=core-it-infra-prod

# If missing, create it
gcloud compute networks subnets create proxy-only-subnet \
  --purpose=REGIONAL_MANAGED_PROXY \
  --role=ACTIVE \
  --region=us-central1 \
  --network=vpc-spoke \
  --range=10.129.0.0/23 \
  --project=core-it-infra-prod
```

#### Issue: SSL Certificate Error

**Symptoms**:
- "NET::ERR_CERT_AUTHORITY_INVALID"
- Browser shows certificate warning

**Solutions**:

**A. Self-Signed Certificate (Expected)**:
- This is normal for self-signed certificates
- Click "Advanced" → "Proceed" in browser
- Or install root CA on client machines

**B. Certificate Mismatch**:
```bash
# Check certificate CN matches hostname
openssl x509 -in cert/fullchain.pem -noout -subject

# Should show: CN=jenkins.np.learningmyway.space
```

**C. Certificate Expired**:
```bash
# Check certificate validity
openssl x509 -in cert/fullchain.pem -noout -dates

# Generate new certificate if expired
cd cert
openssl req -new -x509 -key jenkins.key -out fullchain.pem -days 365 \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=jenkins.np.learningmyway.space"

# Redeploy load balancer
cd ../jenkins-ilb
terraform apply -replace=google_compute_region_ssl_certificate.jenkins_ssl
```

### 3. DNS Issues

#### Issue: DNS Not Resolving

**Symptoms**:
- `jenkins.np.learningmyway.space` does not resolve
- nslookup returns "server can't find"

**Diagnosis**:
```bash
# Check DNS zone exists
gcloud dns managed-zones describe jenkins-private-zone \
  --project=core-it-infra-prod

# Check DNS records
gcloud dns record-sets list \
  --zone=jenkins-private-zone \
  --project=core-it-infra-prod

# Test from Jenkins server
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='nslookup jenkins.np.learningmyway.space'
```

**Solutions**:

**A. DNS Zone Not Created**:
```bash
cd dns-jenkins
terraform apply -auto-approve
```

**B. DNS Zone Not Attached to VPC**:
```bash
# Check zone visibility
gcloud dns managed-zones describe jenkins-private-zone \
  --project=core-it-infra-prod \
  --format="value(privateVisibilityConfig)"

# Should show vpc-spoke
```

**C. Wrong VPC Attached**:
```bash
# Update DNS zone to correct VPC
# Edit dns-jenkins/main.tf and reapply
cd dns-jenkins
terraform apply -auto-approve
```

**D. DNS Record Points to Wrong IP**:
```bash
# Check A record
gcloud dns record-sets describe jenkins.np.learningmyway.space. \
  --zone=jenkins-private-zone \
  --type=A \
  --project=core-it-infra-prod

# Should return 10.10.10.50
# If wrong, update terraform and reapply
```

**E. DNS Caching Issue**:
```bash
# Wait for TTL to expire (300 seconds)
# Or flush systemd-resolved cache
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo systemd-resolve --flush-caches'
```

### 4. Network Connectivity Issues

#### Issue: Cannot Access Jenkins from Windows Test VM

**Symptoms**:
- DNS resolves correctly
- But HTTPS connection times out

**Diagnosis**:
```powershell
# From Windows Server PowerShell

# Test DNS
Resolve-DnsName jenkins.np.learningmyway.space

# Test connectivity to Load Balancer
Test-NetConnection -ComputerName 10.10.10.50 -Port 443

# Test connectivity to Jenkins server directly
Test-NetConnection -ComputerName <jenkins-internal-ip> -Port 8080

# Check routing
Get-NetRoute

# Trace route
Test-NetConnection 10.10.10.50 -TraceRoute
```

**Solutions**:

**A. Firewall Blocking Traffic**:
```bash
# Check firewall rules allow traffic between subnets
gcloud compute firewall-rules list \
  --filter="network=vpc-spoke" \
  --project=core-it-infra-prod

# Create rule if missing
gcloud compute firewall-rules create allow-internal-https \
  --network=vpc-spoke \
  --action=allow \
  --direction=ingress \
  --source-ranges=10.10.0.0/16 \
  --rules=tcp:443,tcp:8080 \
  --project=core-it-infra-prod
```

**B. Windows Firewall Blocking Outbound**:
```powershell
# Disable Windows Firewall temporarily for testing
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Test again
Test-NetConnection -ComputerName 10.10.10.50 -Port 443

# Re-enable firewall and add specific rule
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
New-NetFirewallRule -DisplayName "Allow HTTPS Out" -Direction Outbound -Protocol TCP -RemotePort 443 -Action Allow
```

**C. VMs in Different Subnets**:
```bash
# Verify both VMs are in same VPC
gcloud compute instances describe windows-test-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --format="get(networkInterfaces[0].network)"

gcloud compute instances describe jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --format="get(networkInterfaces[0].network)"

# Both should show projects/core-it-infra-prod/global/networks/vpc-spoke
```

#### Issue: VPC Peering Not Working

**Symptoms**:
- Cannot access resources between hub and spoke VPCs
- Traffic not routing between VPCs

**Diagnosis**:
```bash
# Check peering status
gcloud compute networks peerings list \
  --network=vpc-spoke \
  --project=core-it-infra-prod

gcloud compute networks peerings list \
  --network=vpc-hub \
  --project=networkingglobal-prod

# Should show STATE: ACTIVE
```

**Solutions**:

**A. Peering Not Created**:
```bash
# Create bidirectional peering
gcloud compute networks peerings create spoke-to-hub \
  --network=vpc-spoke \
  --peer-network=vpc-hub \
  --peer-project=networkingglobal-prod \
  --project=core-it-infra-prod

gcloud compute networks peerings create hub-to-spoke \
  --network=vpc-hub \
  --peer-network=vpc-spoke \
  --peer-project=core-it-infra-prod \
  --project=networkingglobal-prod
```

**B. Peering in INACTIVE State**:
```bash
# Delete and recreate peering
gcloud compute networks peerings delete spoke-to-hub \
  --network=vpc-spoke \
  --project=core-it-infra-prod

gcloud compute networks peerings delete hub-to-spoke \
  --network=vpc-hub \
  --project=networkingglobal-prod

# Recreate with correct settings
# Follow Step A above
```

**C. Custom Route Advertisement Needed**:
```bash
# Update peering to export custom routes
gcloud compute networks peerings update spoke-to-hub \
  --network=vpc-spoke \
  --export-custom-routes \
  --project=core-it-infra-prod

gcloud compute networks peerings update hub-to-spoke \
  --network=vpc-hub \
  --export-custom-routes \
  --project=networkingglobal-prod
```

### 5. Terraform Issues

#### Issue: Terraform Apply Fails

**Symptoms**:
- Error during terraform apply
- Resource already exists
- Insufficient permissions

**Solutions**:

**A. Resource Already Exists**:
```bash
# Import existing resource
terraform import <resource_type>.<resource_name> <resource_id>

# Or destroy and recreate
terraform destroy -target=<resource>
terraform apply
```

**B. State Lock Error**:
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

**C. Authentication Error**:
```bash
# Re-authenticate
gcloud auth application-default login

# Set correct project
gcloud config set project core-it-infra-prod
```

**D. API Not Enabled**:
```bash
# Enable required APIs
gcloud services enable compute.googleapis.com --project=core-it-infra-prod
gcloud services enable dns.googleapis.com --project=core-it-infra-prod
```

**E. Quota Exceeded**:
```bash
# Check quotas
gcloud compute project-info describe --project=core-it-infra-prod

# Request quota increase via GCP Console
```

**F. Terraform State Corruption**:
```bash
# Backup state
cp terraform.tfstate terraform.tfstate.backup

# Pull fresh state
terraform state pull > terraform.tfstate

# Or reinitialize
rm -rf .terraform
terraform init
```

### 6. Performance Issues

#### Issue: Jenkins Slow or Unresponsive

**Diagnosis**:
```bash
# Check VM resources
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='top -n 1'

# Check disk usage
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='df -h'

# Check memory
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='free -h'

# Check Jenkins logs
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo journalctl -u jenkins -n 100 | grep -i error'
```

**Solutions**:

**A. Insufficient Memory**:
```bash
# Increase VM size
cd jenkins-vm
# Edit terraform.tfvars: machine_type = "e2-standard-4"
terraform apply

# Or use gcloud
gcloud compute instances set-machine-type jenkins-server \
  --machine-type=e2-standard-4 \
  --zone=us-central1-a \
  --project=core-it-infra-prod
```

**B. Disk Full**:
```bash
# Increase data disk size
gcloud compute disks resize jenkins-data-disk \
  --size=50GB \
  --zone=us-central1-a \
  --project=core-it-infra-prod

# Expand filesystem
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo resize2fs /dev/sdb'

# Clean up old builds
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo find /jenkins/jenkins_home/jobs/*/builds -type d -mtime +30 -exec rm -rf {} \;'
```

**C. Too Many Jenkins Plugins**:
- Access Jenkins UI
- Manage Jenkins → Manage Plugins
- Uninstall unused plugins
- Restart Jenkins

**D. Java Heap Size**:
```bash
# Increase Java heap
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap

# Edit Jenkins configuration
sudo vi /usr/lib/systemd/system/jenkins.service

# Add to Environment line:
Environment="JAVA_OPTS=-Xmx4g -Xms2g"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart jenkins
```

### 7. Security Issues

#### Issue: Cannot Enable IAP

**Symptoms**:
- IAP tunnel fails to establish
- Permission denied errors

**Solutions**:

**A. Configure OAuth Consent Screen**:
1. Go to GCP Console → APIs & Services → OAuth consent screen
2. Fill in required information
3. Add test users if using internal app type

**B. Grant IAP Permissions**:
```bash
# Add IAP-secured Tunnel User role
gcloud projects add-iam-policy-binding core-it-infra-prod \
  --member='user:YOUR-EMAIL@example.com' \
  --role='roles/iap.tunnelResourceAccessor'
```

**C. Enable IAP API**:
```bash
gcloud services enable iap.googleapis.com --project=core-it-infra-prod
```

#### Issue: Firewall Rules Too Permissive

**Solution**: Review and tighten firewall rules

```bash
# List all firewall rules
gcloud compute firewall-rules list --project=core-it-infra-prod

# Update rule to be more restrictive
gcloud compute firewall-rules update RULE_NAME \
  --source-ranges=10.10.0.0/16 \
  --project=core-it-infra-prod
```

### 8. Common Error Messages

#### "Error 403: Forbidden"

**Cause**: Insufficient permissions

**Solution**:
```bash
# Check your permissions
gcloud projects get-iam-policy core-it-infra-prod \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:YOUR-EMAIL@example.com"

# Request required permissions from admin
```

#### "Error 409: Resource already exists"

**Cause**: Resource name conflict

**Solution**:
```bash
# Option 1: Import existing resource
terraform import google_compute_instance.jenkins_server jenkins-server

# Option 2: Use different name in terraform
# Edit main.tf and change resource name
```

#### "Backend service has no healthy backends"

**Cause**: Health check failing

**Solution**: See [Load Balancer Issues](#issue-load-balancer-shows-unhealthy) above

#### "DNS name does not resolve"

**Cause**: DNS configuration issue

**Solution**: See [DNS Issues](#issue-dns-not-resolving) above

---

## Maintenance and Operations

### Regular Maintenance Tasks

#### 1. Update Jenkins

```bash
# SSH to Jenkins server
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap

# Update Jenkins
sudo dnf update jenkins -y

# Restart service
sudo systemctl restart jenkins
```

#### 2. Backup Jenkins Data

```bash
# Create snapshot of data disk
gcloud compute disks snapshot jenkins-data-disk \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --snapshot-names=jenkins-backup-$(date +%Y%m%d)

# List snapshots
gcloud compute snapshots list --project=core-it-infra-prod
```

#### 3. Monitor Resource Usage

```bash
# Check VM metrics in GCP Console
# Compute Engine → VM instances → jenkins-server → Monitoring

# Or use gcloud
gcloud compute instances describe jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod
```

#### 4. Review Security

```bash
# Audit firewall rules
gcloud compute firewall-rules list --project=core-it-infra-prod

# Review IAM permissions
gcloud projects get-iam-policy core-it-infra-prod

# Check for OS updates
gcloud compute ssh jenkins-server \
  --zone=us-central1-a \
  --project=core-it-infra-prod \
  --tunnel-through-iap \
  --command='sudo dnf check-update'
```

#### 5. Certificate Renewal

Self-signed certificates expire after 365 days:

```bash
# Check certificate expiration
openssl x509 -in cert/fullchain.pem -noout -enddate

# Generate new certificate before expiration
cd cert
openssl req -new -x509 -key jenkins.key -out fullchain.pem -days 365 \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=jenkins.np.learningmyway.space"

# Redeploy load balancer with new certificate
cd ../jenkins-ilb
terraform apply
```

### Scaling Considerations

#### Scale Up (Vertical Scaling)

```bash
# Increase VM size
cd jenkins-vm
# Edit terraform.tfvars: machine_type = "e2-standard-4"
terraform apply

# Increase disk size
gcloud compute disks resize jenkins-data-disk \
  --size=100GB \
  --zone=us-central1-a \
  --project=core-it-infra-prod
```

#### Scale Out (Horizontal Scaling)

To add more Jenkins servers:
1. Deploy additional Jenkins VMs
2. Add them to the instance group
3. Configure Jenkins in primary-agent architecture
4. Load balancer automatically distributes traffic

### Monitoring and Alerting

**Recommended Monitoring**:
- VM CPU and memory usage
- Disk space usage
- Jenkins service status
- Load balancer health
- Backend service health
- Network traffic

**Set Up Alerts**:
```bash
# Example: Alert on high CPU
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Jenkins High CPU" \
  --condition-display-name="CPU > 80%" \
  --condition-threshold-value=0.8 \
  --condition-threshold-duration=300s
```

### Cost Optimization

**Current Costs (Estimate)**:
- Jenkins VM (e2-standard-2): ~$50/month
- Persistent disks (40 GB total): ~$7/month
- Load balancer: ~$20/month
- Network egress: Variable
- **Total: ~$77-100/month**

**Cost Saving Tips**:
1. Stop VMs when not in use:
   ```bash
   gcloud compute instances stop jenkins-server \
     --zone=us-central1-a \
     --project=core-it-infra-prod
   ```

2. Use committed use discounts for production
3. Delete test resources (Windows VM) when not needed
4. Use preemptible VMs for Jenkins agents (not primary)
5. Enable disk compression
6. Clean up old Jenkins builds regularly

---

## Cleanup

### Destroy Individual Components

Destroy in reverse order of deployment:

#### 1. Destroy Windows Test VM (if deployed)
```bash
cd windows-test-vm
terraform destroy -auto-approve
```

#### 2. Destroy DNS Configuration
```bash
cd ../dns-jenkins
terraform destroy -auto-approve
```

#### 3. Destroy Internal Load Balancer
```bash
cd ../jenkins-ilb
terraform destroy -auto-approve
```

#### 4. Destroy Jenkins VM
```bash
cd ../jenkins-vm
terraform destroy -auto-approve
```

#### 5. Destroy Core IT Infrastructure
```bash
cd ../core-it-infrastructure
terraform destroy -auto-approve
```

#### 6. Destroy Network Infrastructure
```bash
cd ../Networkingglobal
terraform destroy -auto-approve
```

### Delete VPC Peering
```bash
# Delete peering from spoke
gcloud compute networks peerings delete spoke-to-hub \
  --network=vpc-spoke \
  --project=core-it-infra-prod

# Delete peering from hub
gcloud compute networks peerings delete hub-to-spoke \
  --network=vpc-hub \
  --project=networkingglobal-prod
```

### Clean Up Manual Resources

```bash
# Delete proxy-only subnet
gcloud compute networks subnets delete proxy-only-subnet \
  --region=us-central1 \
  --project=core-it-infra-prod

# Delete firewall rules (if created manually)
gcloud compute firewall-rules delete allow-ilb-to-jenkins --project=core-it-infra-prod
gcloud compute firewall-rules delete allow-health-checks --project=core-it-infra-prod
gcloud compute firewall-rules delete allow-proxy-to-jenkins --project=core-it-infra-prod

# Delete disk snapshots
gcloud compute snapshots list --project=core-it-infra-prod
gcloud compute snapshots delete SNAPSHOT_NAME --project=core-it-infra-prod
```

### Verify Cleanup
```bash
# Check remaining resources
gcloud compute instances list --project=core-it-infra-prod
gcloud compute disks list --project=core-it-infra-prod
gcloud compute forwarding-rules list --project=core-it-infra-prod
gcloud compute backend-services list --project=core-it-infra-prod
gcloud dns managed-zones list --project=core-it-infra-prod
```

---

## Appendix

### A. Architecture Decisions

1. **Internal Load Balancer**: Chosen for security - Jenkins not exposed to internet
2. **Private DNS**: Enables hostname-based access, easier to remember than IP
3. **Hub-Spoke Network**: Scalable architecture for multiple applications
4. **Rocky Linux**: Stable, RHEL-compatible, free
5. **Separate Data Disk**: Easier backups and disk management

### B. Security Best Practices

- ✅ No external IPs on VMs
- ✅ IAP for SSH/RDP access
- ✅ HTTPS with SSL certificates
- ✅ Firewall rules limiting access
- ✅ Private DNS zones
- ✅ Network segmentation (hub-spoke)
- ✅ VPC peering for inter-project communication

### C. Production Recommendations

For production deployment, consider:

1. **Use Managed Certificates**: Google-managed SSL certificates
2. **Enable Cloud Armor**: WAF protection for load balancer
3. **Set Up Monitoring**: Cloud Monitoring with alerts
4. **Enable Logging**: VPC Flow Logs, Load Balancer logs
5. **Implement Backup**: Automated snapshot schedule
6. **Use Cloud NAT**: For outbound internet from private VMs
7. **Deploy Multi-Region**: For high availability
8. **Implement DR Plan**: Disaster recovery procedures
9. **Use Service Accounts**: With principle of least privilege
10. **Enable Binary Authorization**: For container security

### D. Useful Commands Reference

```bash
# Quick status check
gcloud compute instances list --project=core-it-infra-prod
gcloud compute backend-services get-health jenkins-backend-service \
  --region=us-central1 --project=core-it-infra-prod

# Quick Jenkins access
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  -- -L 8080:localhost:8080

# Quick password retrieval
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword'

# Quick health check
curl -k https://10.10.10.50/ (from within VPC)

# Quick DNS test
nslookup jenkins.np.learningmyway.space

# Create snapshot
gcloud compute disks snapshot jenkins-data-disk \
  --zone=us-central1-a --project=core-it-infra-prod

# Start/Stop VM
gcloud compute instances stop jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod
gcloud compute instances start jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod
```

### E. Additional Resources

- [GCP Internal Load Balancer Documentation](https://cloud.google.com/load-balancing/docs/l7-internal)
- [GCP Cloud DNS Documentation](https://cloud.google.com/dns/docs)
- [GCP VPC Peering Documentation](https://cloud.google.com/vpc/docs/vpc-peering)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

### F. Known Limitations

1. **Self-Signed Certificates**: Require manual trust installation
2. **Single Jenkins Instance**: No high availability (can be extended)
3. **Regional Deployment**: Single region (us-central1)
4. **Manual DNS Management**: External DNS requires separate setup
5. **No Auto-Scaling**: Instance group size fixed at 1

### G. Version Information

- **Terraform**: >= 1.0
- **GCP Provider**: >= 4.0
- **Jenkins**: Latest LTS (installed from repository)
- **Rocky Linux**: 9 (latest)
- **Java**: OpenJDK 17

---

## Support and Contributions

For issues or questions:
1. Check troubleshooting section above
2. Review GCP logs and monitoring
3. Verify all prerequisites are met
4. Check Terraform state and apply

---

**Document Version**: 1.0  
**Last Updated**: February 13, 2026  
**Author**: Infrastructure Team  
**Project**: GCP Jenkins POC
