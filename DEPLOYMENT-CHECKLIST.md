# GCP Jenkins POC - Deployment Checklist & Quick Reference

## Pre-Deployment Checklist

### ✅ Prerequisites Setup

#### 1. Local Environment
- [ ] gcloud CLI installed and configured
- [ ] Terraform installed (v1.0+)
- [ ] Git installed
- [ ] Text editor/IDE (VS Code recommended)

#### 2. GCP Authentication
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project core-it-infra-prod
```

#### 3. GCP Projects Created
- [ ] networkingglobal-prod (Hub VPC project)
- [ ] core-it-infra-prod (Spoke VPC project)

#### 4. Enable Required APIs
```bash
# For networkingglobal-prod
gcloud services enable compute.googleapis.com servicenetworking.googleapis.com \
  --project=networkingglobal-prod

# For core-it-infra-prod
gcloud services enable compute.googleapis.com dns.googleapis.com \
  servicenetworking.googleapis.com iap.googleapis.com \
  --project=core-it-infra-prod
```

#### 5. IAM Permissions
- [ ] Compute Admin
- [ ] Network Admin
- [ ] DNS Administrator
- [ ] IAP Tunnel Resource Accessor
- [ ] Service Account Admin

#### 6. SSL Certificates Generated
```bash
mkdir -p cert && cd cert

# Private key
openssl genrsa -out jenkins.key 2048

# Certificate
openssl req -new -x509 -key jenkins.key -out fullchain.pem -days 365 \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=jenkins.np.learningmyway.space"

# Root CA
openssl req -new -x509 -key jenkins.key -out root-ca.crt -days 365 \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=Root CA"

cd ..
```

---

## Deployment Sequence

### 📋 Step-by-Step Deployment

#### Phase 1: Network Foundation (10-15 minutes)

**1.1 Deploy Hub VPC**
```bash
cd Networkingglobal
terraform init
terraform plan
terraform apply -auto-approve
terraform output
cd ..
```
- [ ] Hub VPC created
- [ ] Subnet-vpn created
- [ ] Firewall rules in place

**1.2 Deploy Spoke VPC**
```bash
cd core-it-infrastructure
terraform init
terraform plan
terraform apply -auto-approve
terraform output
cd ..
```
- [ ] Spoke VPC created
- [ ] Subnet-jenkins created
- [ ] Firewall rules in place

**1.3 Configure VPC Peering**
```bash
# Spoke to Hub
gcloud compute networks peerings create spoke-to-hub \
  --network=vpc-spoke --peer-network=vpc-hub \
  --peer-project=networkingglobal-prod \
  --project=core-it-infra-prod

# Hub to Spoke
gcloud compute networks peerings create hub-to-spoke \
  --network=vpc-hub --peer-network=vpc-spoke \
  --peer-project=core-it-infra-prod \
  --project=networkingglobal-prod

# Verify
gcloud compute networks peerings list --network=vpc-spoke \
  --project=core-it-infra-prod
```
- [ ] Peering created
- [ ] Status: ACTIVE

**1.4 Create Proxy-Only Subnet (Required for ILB)**
```bash
gcloud compute networks subnets create proxy-only-subnet \
  --purpose=REGIONAL_MANAGED_PROXY --role=ACTIVE \
  --region=us-central1 --network=vpc-spoke \
  --range=10.129.0.0/23 --project=core-it-infra-prod

# Verify
gcloud compute networks subnets describe proxy-only-subnet \
  --region=us-central1 --project=core-it-infra-prod
```
- [ ] Proxy-only subnet created

---

#### Phase 2: Jenkins VM (15-20 minutes)

**2.1 Deploy Jenkins VM**
```bash
cd jenkins-vm
terraform init
terraform plan
terraform apply -auto-approve
terraform output jenkins_vm_internal_ip
cd ..
```
- [ ] VM deployed
- [ ] Boot disk created
- [ ] Data disk created and mounted

**2.2 Monitor Installation (wait 5-10 minutes)**
```bash
# Watch startup logs
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo tail -f /var/log/startup-script.log'
```
- [ ] Java installed
- [ ] Jenkins installed
- [ ] Service started
- [ ] Initial password generated

**2.3 Verify Jenkins Service**
```bash
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl status jenkins'
```
- [ ] Service active (running)

**2.4 Get Initial Admin Password**
```bash
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword'
```
- [ ] Password retrieved: ________________

---

#### Phase 3: Load Balancer (10-15 minutes)

**3.1 Configure Firewall for Load Balancer**
```bash
# Health checks and proxy traffic
gcloud compute firewall-rules create allow-ilb-to-jenkins \
  --network=vpc-spoke --action=allow --direction=ingress \
  --source-ranges=10.129.0.0/23,35.191.0.0/16,130.211.0.0/22 \
  --target-tags=jenkins-server --rules=tcp:8080,tcp:80 \
  --project=core-it-infra-prod
```
- [ ] Firewall rule created

**3.2 Deploy Internal HTTPS Load Balancer**
```bash
cd jenkins-ilb

# Verify certificates exist
ls -la ../cert/jenkins.key
ls -la ../cert/fullchain.pem

terraform init
terraform plan
terraform apply -auto-approve
terraform output load_balancer_ip
cd ..
```
- [ ] SSL certificate uploaded
- [ ] Backend service created
- [ ] Health check configured
- [ ] Instance group created
- [ ] Forwarding rule created
- [ ] Static IP: 10.10.10.50

**3.3 Verify Load Balancer Health (wait 2-3 minutes)**
```bash
# Check health status
gcloud compute backend-services get-health jenkins-backend-service \
  --region=us-central1 --project=core-it-infra-prod

# Should show healthState: HEALTHY
```
- [ ] Backend status: HEALTHY

**3.4 Test Load Balancer Access**
```bash
# From Jenkins server
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='curl -k https://10.10.10.50/'
```
- [ ] Returns Jenkins HTML

---

#### Phase 4: DNS Configuration (5 minutes)

**4.1 Deploy Private DNS Zone**
```bash
cd dns-jenkins
terraform init
terraform plan
terraform apply -auto-approve
terraform output
cd ..
```
- [ ] Private DNS zone created
- [ ] A record created
- [ ] CNAME record created

**4.2 Verify DNS Resolution (wait 5 minutes for TTL)**
```bash
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='nslookup jenkins.np.learningmyway.space'
```
- [ ] Resolves to: 10.10.10.50

**4.3 Test HTTPS Access via Hostname**
```bash
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='curl -k https://jenkins.np.learningmyway.space/'
```
- [ ] Returns Jenkins HTML

---

#### Phase 5: Testing & Validation (Optional, 10 minutes)

**5.1 Deploy Windows Test VM (Optional)**
```bash
cd windows-test-vm
terraform init
terraform plan
terraform apply -auto-approve
cd ..
```
- [ ] Windows VM created

**5.2 Access Windows Server**
```bash
# Reset password
gcloud compute reset-windows-password windows-test-server \
  --zone=us-central1-a --project=core-it-infra-prod --user=admin

# Start RDP tunnel
gcloud compute start-iap-tunnel windows-test-server 3389 \
  --local-host-port=localhost:3389 \
  --zone=us-central1-a --project=core-it-infra-prod
```
- [ ] RDP connection successful

**5.3 Test from Windows**
```powershell
# In Windows PowerShell
Resolve-DnsName jenkins.np.learningmyway.space
Test-NetConnection -ComputerName 10.10.10.50 -Port 443
Invoke-WebRequest -Uri https://jenkins.np.learningmyway.space -UseBasicParsing
```
- [ ] DNS resolves
- [ ] Port 443 open
- [ ] HTTPS responds

---

## Post-Deployment Validation

### ✅ System Health Check

```bash
# Run all these commands to verify deployment

# 1. Check VM is running
gcloud compute instances describe jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod \
  --format="value(status)"
# Expected: RUNNING

# 2. Check Jenkins service
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl is-active jenkins'
# Expected: active

# 3. Check load balancer health
gcloud compute backend-services get-health jenkins-backend-service \
  --region=us-central1 --project=core-it-infra-prod
# Expected: healthState: HEALTHY

# 4. Check DNS
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='nslookup jenkins.np.learningmyway.space'
# Expected: Returns 10.10.10.50

# 5. Check disk mount
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='df -h | grep /jenkins'
# Expected: Shows /dev/sdb mounted on /jenkins

# 6. Test HTTPS access
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='curl -k -I https://jenkins.np.learningmyway.space'
# Expected: HTTP 200 OK or 403 Forbidden (Jenkins login page)
```

### ✅ Component Checklist

- [ ] **Network Layer**
  - [ ] VPC-hub exists
  - [ ] VPC-spoke exists  
  - [ ] VPC peering active
  - [ ] Proxy-only subnet created
  - [ ] All firewall rules in place

- [ ] **Compute Layer**
  - [ ] Jenkins VM running
  - [ ] Boot disk attached
  - [ ] Data disk attached and mounted at /jenkins
  - [ ] Jenkins service active
  - [ ] Ports 8080 and 80 accessible

- [ ] **Load Balancer Layer**
  - [ ] SSL certificate uploaded
  - [ ] Backend service created
  - [ ] Health check passing
  - [ ] Instance group has jenkins-server
  - [ ] Forwarding rule points to 10.10.10.50
  - [ ] HTTPS traffic flows correctly

- [ ] **DNS Layer**
  - [ ] Private DNS zone created
  - [ ] A record: jenkins.np.learningmyway.space → 10.10.10.50
  - [ ] CNAME record created
  - [ ] DNS resolution works from VPC

- [ ] **Security Layer**
  - [ ] No external IPs on VMs
  - [ ] IAP access configured
  - [ ] Firewall rules restrictive
  - [ ] SSL/TLS enabled
  - [ ] IAM permissions set

---

## Access Methods

### Method 1: SSH Tunnel (Recommended for Testing)
```bash
# Create tunnel from Jenkins VM to local machine
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  -- -L 8080:localhost:8080

# Open browser to: http://localhost:8080
```

### Method 2: Via Load Balancer (From Windows Test VM or VPN)
```
# Browser URL
https://jenkins.np.learningmyway.space

# Or using IP directly
https://10.10.10.50
```

### Method 3: Direct SSH (For Administration)
```bash
# SSH to Jenkins server
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap

# Then access locally
curl http://localhost:8080
```

---

## Configuration Summary

### Network Configuration

| Component | Value |
|-----------|-------|
| Hub VPC | vpc-hub |
| Hub Subnet | subnet-vpn (20.20.0.0/16) |
| Spoke VPC | vpc-spoke |
| Spoke Subnet | subnet-jenkins (10.10.0.0/16) |
| Proxy Subnet | 10.129.0.0/23 |
| IAP Range | 35.235.240.0/20 |
| Health Check Range | 35.191.0.0/16, 130.211.0.0/22 |

### Jenkins Configuration

| Component | Value |
|-----------|-------|
| Project | core-it-infra-prod |
| Region | us-central1 |
| Zone | us-central1-a |
| VM Name | jenkins-server |
| Machine Type | e2-standard-2 |
| OS | Rocky Linux 9 |
| Jenkins Port | 8080 (internal) |
| Redirect Port | 80 → 8080 |
| Jenkins Home | /jenkins/jenkins_home |
| Boot Disk | 20 GB |
| Data Disk | 20 GB |

### Load Balancer Configuration

| Component | Value |
|-----------|-------|
| Type | Regional Internal HTTPS |
| IP Address | 10.10.10.50 (static) |
| Frontend Protocol | HTTPS (443) |
| Backend Protocol | HTTP (8080) |
| Health Check | /login endpoint |
| SSL Certificate | Self-signed (jenkins.key, fullchain.pem) |

### DNS Configuration

| Component | Value |
|-----------|-------|
| Zone Name | jenkins-private-zone |
| Domain | learningmyway.space |
| Visibility | Private (vpc-spoke) |
| A Record | jenkins.np.learningmyway.space |
| IP Address | 10.10.10.50 |
| TTL | 300 seconds |

---

## Architecture Diagram (ASCII)

```
╔════════════════════════════════════════════════════════════════════╗
║                    EXTERNAL ACCESS (Optional)                      ║
║                                                                    ║
║  Internet/VPN Users → Firezone Gateway (WireGuard)                ║
╚════════════════════════════════════════════════════════════════════╝
                                ↓
╔════════════════════════════════════════════════════════════════════╗
║            PROJECT: networkingglobal-prod (Hub)                    ║
║  ┌──────────────────────────────────────────────────────────────┐ ║
║  │  VPC: vpc-hub (20.20.0.0/16)                                 │ ║
║  │  ┌─────────────────────────────────────────────────────────┐ │ ║
║  │  │  Subnet: subnet-vpn (20.20.0.0/16, us-central1)         │ │ ║
║  │  │  - Firezone Gateway VM                                   │ │ ║
║  │  │  - Firewall: WireGuard (UDP:51820)                      │ │ ║
║  │  │  - Firewall: IAP SSH (TCP:22)                           │ │ ║
║  │  └─────────────────────────────────────────────────────────┘ │ ║
║  └──────────────────────────────────────────────────────────────┘ ║
╚════════════════════════════════════════════════════════════════════╝
                                ↓
                          VPC PEERING
                    (spoke-to-hub / hub-to-spoke)
                                ↓
╔════════════════════════════════════════════════════════════════════╗
║            PROJECT: core-it-infra-prod (Spoke)                     ║
║  ┌──────────────────────────────────────────────────────────────┐ ║
║  │  VPC: vpc-spoke (10.10.0.0/16)                               │ ║
║  │                                                                │ ║
║  │  ┌─────────────────────────────────────────────────────────┐ │ ║
║  │  │  Subnet: subnet-jenkins (10.10.0.0/16, us-central1)     │ │ ║
║  │  │                                                           │ │ ║
║  │  │  ┌─────────────────────────────────────────────────┐    │ │ ║
║  │  │  │  Jenkins Server VM                              │    │ │ ║
║  │  │  │  - Name: jenkins-server                         │    │ │ ║
║  │  │  │  - OS: Rocky Linux 9                            │    │ │ ║
║  │  │  │  - Type: e2-standard-2                          │    │ │ ║
║  │  │  │  - Internal IP: 10.10.x.x                       │    │ │ ║
║  │  │  │  - No External IP                               │    │ │ ║
║  │  │  │  - Boot Disk: 20 GB                             │    │ │ ║
║  │  │  │  - Data Disk: 20 GB (/jenkins)                  │    │ │ ║
║  │  │  │  - Jenkins: Port 8080                           │    │ │ ║
║  │  │  │  - Port Redirect: 80→8080                       │    │ │ ║
║  │  │  └─────────────────────────────────────────────────┘    │ │ ║
║  │  │                          ↑                                │ ║
║  │  │                          │ HTTP:8080                      │ ║
║  │  │                          │                                │ ║
║  │  │  ┌─────────────────────────────────────────────────┐    │ │ ║
║  │  │  │  Instance Group: jenkins-instance-group         │    │ │ ║
║  │  │  │  - Members: jenkins-server                      │    │ │ ║
║  │  │  │  - Named Ports: http:8080, http-alt:80          │    │ │ ║
║  │  │  └─────────────────────────────────────────────────┘    │ │ ║
║  │  │                          ↑                                │ ║
║  │  │                          │ Health Check: /login           │ ║
║  │  │                          │                                │ ║
║  │  │  ┌─────────────────────────────────────────────────┐    │ │ ║
║  │  │  │  Backend Service: jenkins-backend-service       │    │ │ ║
║  │  │  │  - Protocol: HTTP                               │    │ │ ║
║  │  │  │  - Type: INTERNAL_MANAGED                       │    │ │ ║
║  │  │  │  - Health Check: jenkins-health-check           │    │ │ ║
║  │  │  └─────────────────────────────────────────────────┘    │ │ ║
║  │  │                          ↑                                │ ║
║  │  │                          │ HTTPS:443                      │ ║
║  │  │                          │                                │ ║
║  │  │  ┌─────────────────────────────────────────────────┐    │ │ ║
║  │  │  │  Forwarding Rule: jenkins-forwarding-rule       │    │ │ ║
║  │  │  │  - Static IP: 10.10.10.50                       │    │ │ ║
║  │  │  │  - Protocol: HTTPS                              │    │ │ ║
║  │  │  │  - Port: 443                                    │    │ │ ║
║  │  │  │  - SSL Certificate: jenkins-ssl-certificate     │    │ │ ║
║  │  │  │  - Type: INTERNAL_MANAGED                       │    │ │ ║
║  │  │  └─────────────────────────────────────────────────┘    │ │ ║
║  │  │                          ↑                                │ ║
║  │  └──────────────────────────│────────────────────────────── │ ║
║  │                             │                                │ ║
║  │  ┌──────────────────────────│────────────────────────────┐ │ ║
║  │  │  Proxy-Only Subnet (10.129.0.0/23)                    │ │ ║
║  │  │  - Purpose: REGIONAL_MANAGED_PROXY                    │ │ ║
║  │  │  - Required for Internal HTTPS Load Balancers         │ │ ║
║  │  └───────────────────────────────────────────────────────┘ │ ║
║  │                                                              │ ║
║  │  ┌──────────────────────────────────────────────────────┐  │ ║
║  │  │  Private DNS Zone: jenkins-private-zone              │  │ ║
║  │  │  - Domain: learningmyway.space                       │  │ ║
║  │  │  - A Record: jenkins.np.learningmyway.space          │  │ ║
║  │  │  - IP: 10.10.10.50                                   │  │ ║
║  │  │  - CNAME: www.jenkins.np → jenkins.np               │  │ ║
║  │  └──────────────────────────────────────────────────────┘  │ ║
║  │                                                              │ ║
║  │  ┌──────────────────────────────────────────────────────┐  │ ║
║  │  │  Windows Test Server VM (Optional)                   │  │ ║
║  │  │  - OS: Windows Server 2022                           │  │ ║
║  │  │  - Type: e2-standard-2                               │  │ ║
║  │  │  - Access: RDP via IAP                               │  │ ║
║  │  │  - Purpose: DNS/HTTPS testing                        │  │ ║
║  │  └──────────────────────────────────────────────────────┘  │ ║
║  │                                                              │ ║
║  │  Firewall Rules:                                             │ ║
║  │  - allow-iap-ssh: IAP → VMs (TCP:22,3389)                   │ ║
║  │  - allow-ilb-to-jenkins: Proxy/Health → Jenkins              │ ║
║  │  - allow-hub-traffic: Hub VPC → Spoke VPC (TCP:443)         │ ║
║  └──────────────────────────────────────────────────────────────┘ ║
╚════════════════════════════════════════════════════════════════════╝

TRAFFIC FLOW:
1. User → VPN Gateway (Firezone in Hub VPC)
2. Hub VPC → VPC Peering → Spoke VPC
3. User/VM → DNS Query → Private DNS Zone
4. DNS returns: jenkins.np.learningmyway.space = 10.10.10.50
5. User/VM → HTTPS Request → Load Balancer IP (10.10.10.50:443)
6. SSL Termination at Load Balancer
7. Load Balancer → Backend Service (HTTP)
8. Backend Service → Health Check → Jenkins /login
9. Backend Service → Instance Group → Jenkins VM (HTTP:8080)
10. Jenkins processes request and returns response
```

---

## Quick Reference Commands

### Essential Commands Cheat Sheet

```bash
# SSH to Jenkins
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap

# Get Jenkins password
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword'

# Create SSH tunnel
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  -- -L 8080:localhost:8080

# Check VM status
gcloud compute instances describe jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod \
  --format="value(status)"

# Check Jenkins service
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl status jenkins'

# Check load balancer health
gcloud compute backend-services get-health jenkins-backend-service \
  --region=us-central1 --project=core-it-infra-prod

# Test DNS
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='nslookup jenkins.np.learningmyway.space'

# View logs
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo journalctl -u jenkins -n 100'

# Restart Jenkins
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl restart jenkins'

# Create snapshot
gcloud compute disks snapshot jenkins-data-disk \
  --zone=us-central1-a --project=core-it-infra-prod \
  --snapshot-names=jenkins-backup-$(date +%Y%m%d)

# Start/Stop VM
gcloud compute instances stop jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod
gcloud compute instances start jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod
```

---

## Deployment Time Estimates

| Phase | Task | Time | Total |
|-------|------|------|-------|
| 1 | Hub VPC deployment | 5 min | 5 min |
| 1 | Spoke VPC deployment | 5 min | 10 min |
| 1 | VPC peering setup | 2 min | 12 min |
| 1 | Proxy-only subnet | 1 min | 13 min |
| 2 | Jenkins VM deployment | 3 min | 16 min |
| 2 | Jenkins installation wait | 10 min | 26 min |
| 3 | Firewall configuration | 2 min | 28 min |
| 3 | Load balancer deployment | 5 min | 33 min |
| 3 | Health check stabilization | 3 min | 36 min |
| 4 | DNS deployment | 3 min | 39 min |
| 4 | DNS propagation wait | 5 min | 44 min |
| 5 | Windows VM (optional) | 5 min | 49 min |
| - | **Total Deployment Time** | | **40-50 min** |

*Note: Times are approximate and may vary based on GCP region load and network conditions*

---

## Success Criteria

Your deployment is successful when ALL of these are true:

✅ VM Status: `RUNNING`  
✅ Jenkins Service: `active (running)`  
✅ Load Balancer Health: `HEALTHY`  
✅ DNS Resolution: Returns `10.10.10.50`  
✅ HTTPS Access: Returns HTTP 200 or 403  
✅ Disk Mount: `/dev/sdb` mounted on `/jenkins`  
✅ Initial Password: Retrieved successfully  

---

## Troubleshooting Quick Links

- **Service Down**: See [TROUBLESHOOTING-QUICK-GUIDE.md](TROUBLESHOOTING-QUICK-GUIDE.md#issue-1-jenkins-service-down)
- **LB Unhealthy**: See [TROUBLESHOOTING-QUICK-GUIDE.md](TROUBLESHOOTING-QUICK-GUIDE.md#issue-2-load-balancer-unhealthy)
- **DNS Issues**: See [TROUBLESHOOTING-QUICK-GUIDE.md](TROUBLESHOOTING-QUICK-GUIDE.md#issue-3-dns-not-resolving)
- **SSH Problems**: See [TROUBLESHOOTING-QUICK-GUIDE.md](TROUBLESHOOTING-QUICK-GUIDE.md#issue-4-cannot-ssh-to-vm)
- **Complete Guide**: See [COMPLETE-DOCUMENTATION.md](COMPLETE-DOCUMENTATION.md)

---

**Document Version**: 1.0  
**Last Updated**: February 13, 2026
