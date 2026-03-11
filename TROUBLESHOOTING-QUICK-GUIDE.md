# Jenkins Infrastructure POC - Quick Troubleshooting Guide

## Quick Diagnostics

### Health Check Script
Run this script to quickly check the health of all components:

```bash
#!/bin/bash
# Quick health check for Jenkins infrastructure

PROJECT="core-it-infra-prod"
ZONE="us-central1-a"
REGION="us-central1"

echo "=== JENKINS INFRASTRUCTURE HEALTH CHECK ==="
echo ""

# 1. Check VM Status
echo "1. Checking Jenkins VM status..."
gcloud compute instances describe jenkins-server \
  --zone=$ZONE --project=$PROJECT \
  --format="value(status)" 2>&1
echo ""

# 2. Check Jenkins Service
echo "2. Checking Jenkins service..."
gcloud compute ssh jenkins-server \
  --zone=$ZONE --project=$PROJECT \
  --tunnel-through-iap \
  --command='sudo systemctl is-active jenkins' 2>&1
echo ""

# 3. Check Backend Health
echo "3. Checking load balancer health..."
gcloud compute backend-services get-health jenkins-backend-service \
  --region=$REGION --project=$PROJECT 2>&1
echo ""

# 4. Check DNS Resolution
echo "4. Checking DNS resolution..."
gcloud compute ssh jenkins-server \
  --zone=$ZONE --project=$PROJECT \
  --tunnel-through-iap \
  --command='nslookup jenkins.np.learningmyway.space' 2>&1
echo ""

# 5. Check Disk Usage
echo "5. Checking disk usage..."
gcloud compute ssh jenkins-server \
  --zone=$ZONE --project=$PROJECT \
  --tunnel-through-iap \
  --command='df -h | grep -E "Filesystem|/jenkins"' 2>&1
echo ""

echo "=== HEALTH CHECK COMPLETE ==="
```

Save as `health-check.sh`, make executable with `chmod +x health-check.sh`, and run `./health-check.sh`

---

## Common Issues - Quick Fixes

### Issue 1: Jenkins Service Down

**Error**: Service inactive/failed

**Quick Fix**:
```bash
# Restart Jenkins
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl restart jenkins && sleep 10 && sudo systemctl status jenkins'
```

**If still failing**:
```bash
# Check logs
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo journalctl -u jenkins -n 50'

# Common causes:
# - Java not installed: sudo dnf install -y java-17-openjdk
# - Permissions: sudo chown -R jenkins:jenkins /jenkins/jenkins_home
# - Disk unmounted: sudo mount /dev/sdb /jenkins
```

---

### Issue 2: Load Balancer Unhealthy

**Error**: "Backend has no healthy backends"

**Quick Fix**:
```bash
# 1. Check firewall rules for health checks
gcloud compute firewall-rules list --filter="name~health" --project=core-it-infra-prod

# 2. If missing, create:
gcloud compute firewall-rules create allow-health-checks \
  --network=vpc-spoke --action=allow --direction=ingress \
  --source-ranges=35.191.0.0/16,130.211.0.0/22 \
  --target-tags=jenkins-server --rules=tcp:8080 \
  --project=core-it-infra-prod

# 3. Allow proxy subnet
gcloud compute firewall-rules create allow-proxy-to-jenkins \
  --network=vpc-spoke --action=allow --direction=ingress \
  --source-ranges=10.129.0.0/23 --target-tags=jenkins-server \
  --rules=tcp:8080,tcp:80 --project=core-it-infra-prod

# 4. Test Jenkins /login endpoint
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='curl -I http://localhost:8080/login'
```

---

### Issue 3: DNS Not Resolving

**Error**: "server can't find jenkins.np.learningmyway.space"

**Quick Fix**:
```bash
# 1. Check DNS zone exists
gcloud dns managed-zones describe jenkins-private-zone --project=core-it-infra-prod

# 2. Check A record
gcloud dns record-sets list --zone=jenkins-private-zone --project=core-it-infra-prod

# 3. If missing, redeploy:
cd dns-jenkins
terraform apply -auto-approve

# 4. Clear DNS cache
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemd-resolve --flush-caches'

# 5. Wait 5 minutes for DNS TTL, then test
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='dig jenkins.np.learningmyway.space'
```

---

### Issue 4: Cannot SSH to VM

**Error**: "Failed to connect"

**Quick Fix**:
```bash
# 1. Check VM is running
gcloud compute instances describe jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod \
  --format="value(status)"

# 2. If TERMINATED, start it
gcloud compute instances start jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod

# 3. Check IAP firewall rule
gcloud compute firewall-rules describe allow-iap-ssh --project=core-it-infra-prod

# 4. If missing, create:
gcloud compute firewall-rules create allow-iap-ssh \
  --network=vpc-spoke --action=allow --direction=ingress \
  --source-ranges=35.235.240.0/20 --rules=tcp:22 \
  --project=core-it-infra-prod

# 5. Enable IAP API
gcloud services enable iap.googleapis.com --project=core-it-infra-prod
```

---

### Issue 5: Certificate Errors

**Error**: "NET::ERR_CERT_AUTHORITY_INVALID"

**Quick Fix**:
```bash
# This is expected with self-signed certificates
# Option 1: Click "Advanced" → "Proceed" in browser

# Option 2: Install CA certificate
# On Linux (Jenkins or test VMs):
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap

sudo cp /path/to/root-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract

# On Windows: Double-click cert → Install to "Trusted Root Certification Authorities"

# Option 3: Generate new certificate with correct CN
cd cert
openssl req -new -x509 -key jenkins.key -out fullchain.pem -days 365 \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=jenkins.np.learningmyway.space"

# Redeploy load balancer
cd ../jenkins-ilb
terraform apply
```

---

### Issue 6: Disk Full

**Error**: "No space left on device"

**Quick Fix**:
```bash
# 1. Check disk usage
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='df -h'

# 2. Clean old Jenkins builds
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo find /jenkins/jenkins_home/jobs/*/builds -type d -mtime +30 -delete'

# 3. If still full, increase disk size
gcloud compute disks resize jenkins-data-disk \
  --size=50GB --zone=us-central1-a --project=core-it-infra-prod

# 4. Expand filesystem
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo resize2fs /dev/sdb'
```

---

### Issue 7: High CPU/Memory Usage

**Error**: Jenkins slow or unresponsive

**Quick Fix**:
```bash
# 1. Check resources
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='top -b -n 1 | head -20'

# 2. Restart Jenkins
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl restart jenkins'

# 3. Increase VM size (requires stopping VM)
gcloud compute instances stop jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod

gcloud compute instances set-machine-type jenkins-server \
  --machine-type=e2-standard-4 \
  --zone=us-central1-a --project=core-it-infra-prod

gcloud compute instances start jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod

# 4. Wait 2-3 minutes for Jenkins to start, then verify
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl status jenkins'
```

---

### Issue 8: Port Configuration Problems

**Error**: Jenkins on wrong port or not redirecting

**Quick Fix**:
```bash
# Run the setup script to fix port configuration
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap

# Upload the script if not present
# From local machine:
# gcloud compute scp jenkins-vm/setup-jenkins-final.sh jenkins-server:~ \
#   --zone=us-central1-a --project=core-it-infra-prod

# On Jenkins server:
sudo bash setup-jenkins-final.sh

# Verify:
curl http://localhost:8080/login
netstat -tuln | grep -E '80|8080'
```

---

### Issue 9: IAP Not Working

**Error**: "Permission denied" or IAP tunnel fails

**Quick Fix**:
```bash
# 1. Enable IAP API
gcloud services enable iap.googleapis.com --project=core-it-infra-prod

# 2. Grant yourself IAP permissions
gcloud projects add-iam-policy-binding core-it-infra-prod \
  --member='user:YOUR-EMAIL@example.com' \
  --role='roles/iap.tunnelResourceAccessor'

# 3. Check firewall allows IAP
gcloud compute firewall-rules create allow-iap-ssh \
  --network=vpc-spoke --action=allow --direction=ingress \
  --source-ranges=35.235.240.0/20 --rules=tcp:22,tcp:3389 \
  --project=core-it-infra-prod

# 4. Retry connection
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap
```

---

### Issue 10: Terraform Errors

**Error**: Various terraform apply/plan errors

**Quick Fix**:
```bash
# Authentication error
gcloud auth application-default login

# State lock error
terraform force-unlock <LOCK_ID>

# Resource exists error
terraform import <resource_type>.<name> <resource_id>
# Or: terraform destroy -target=<resource> && terraform apply

# API not enabled
gcloud services enable compute.googleapis.com --project=core-it-infra-prod
gcloud services enable dns.googleapis.com --project=core-it-infra-prod

# Corrupted state
cp terraform.tfstate terraform.tfstate.backup
terraform state pull > terraform.tfstate
# Or: rm -rf .terraform && terraform init

# Provider version issues
terraform init -upgrade
```

---

## Emergency Procedures

### Complete Service Restart

```bash
# 1. Stop Jenkins
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl stop jenkins'

# 2. Check data disk
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='df -h | grep /jenkins'

# 3. If unmounted, remount
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo mount /dev/sdb /jenkins'

# 4. Fix permissions
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo chown -R jenkins:jenkins /jenkins/jenkins_home'

# 5. Start Jenkins
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl start jenkins'

# 6. Wait and check
sleep 30
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl status jenkins'
```

### VM Won't Start

```bash
# 1. Check VM status
gcloud compute instances describe jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod

# 2. View serial console logs
gcloud compute instances get-serial-port-output jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod

# 3. Try starting with specific action
gcloud compute instances start jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod

# 4. If boot disk issue, detach/reattach boot disk
# 5. If persistent issue, restore from snapshot
gcloud compute snapshots list --project=core-it-infra-prod
gcloud compute disks create jenkins-data-disk-restore \
  --source-snapshot=SNAPSHOT_NAME \
  --zone=us-central1-a --project=core-it-infra-prod
```

### Complete Rebuild

If everything fails, rebuild from scratch:

```bash
# 1. Create snapshot of data disk (preserve Jenkins data)
gcloud compute disks snapshot jenkins-data-disk \
  --zone=us-central1-a --project=core-it-infra-prod \
  --snapshot-names=jenkins-backup-emergency-$(date +%Y%m%d-%H%M%S)

# 2. Destroy Jenkins VM
cd jenkins-vm
terraform destroy -auto-approve

# 3. Destroy and recreate load balancer
cd ../jenkins-ilb
terraform destroy -auto-approve
terraform apply -auto-approve

# 4. Redeploy Jenkins VM
cd ../jenkins-vm
terraform apply -auto-approve

# 5. If needed, restore data from snapshot
gcloud compute disks create jenkins-data-disk-new \
  --source-snapshot=jenkins-backup-emergency-TIMESTAMP \
  --zone=us-central1-a --project=core-it-infra-prod

# Attach and mount the restored disk
```

---

## Quick Access Commands

### Get Jenkins Initial Password
```bash
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword'
```

### Open SSH Tunnel to Jenkins
```bash
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  -- -L 8080:localhost:8080
```
Then open: http://localhost:8080

### Check All Component Status
```bash
# VM
gcloud compute instances describe jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --format="value(status)"

# Service
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl is-active jenkins'

# Load Balancer
gcloud compute backend-services get-health jenkins-backend-service \
  --region=us-central1 --project=core-it-infra-prod

# DNS
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='nslookup jenkins.np.learningmyway.space'
```

### View Logs
```bash
# Startup script
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo tail -100 /var/log/startup-script.log'

# Jenkins service
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo journalctl -u jenkins -n 100'

# System logs
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo journalctl -n 100'
```

---

## Monitoring Dashboard

Create this script for continuous monitoring:

```bash
#!/bin/bash
# Jenkins Infrastructure Monitoring Dashboard

while true; do
  clear
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║      JENKINS INFRASTRUCTURE MONITORING DASHBOARD           ║"
  echo "║                  $(date '+%Y-%m-%d %H:%M:%S')                      ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  
  # VM Status
  echo "🖥️  VM Status:"
  VM_STATUS=$(gcloud compute instances describe jenkins-server \
    --zone=us-central1-a --project=core-it-infra-prod \
    --format="value(status)" 2>/dev/null)
  echo "   jenkins-server: $VM_STATUS"
  echo ""
  
  # Jenkins Service
  echo "⚙️  Jenkins Service:"
  JENKINS_STATUS=$(gcloud compute ssh jenkins-server \
    --zone=us-central1-a --project=core-it-infra-prod \
    --tunnel-through-iap \
    --command='sudo systemctl is-active jenkins' 2>/dev/null)
  echo "   Status: $JENKINS_STATUS"
  echo ""
  
  # Load Balancer Health
  echo "🔀 Load Balancer Health:"
  gcloud compute backend-services get-health jenkins-backend-service \
    --region=us-central1 --project=core-it-infra-prod 2>/dev/null | \
    grep -E "healthState|ipAddress" | head -4
  echo ""
  
  # Disk Usage
  echo "💾 Disk Usage:"
  gcloud compute ssh jenkins-server \
    --zone=us-central1-a --project=core-it-infra-prod \
    --tunnel-through-iap \
    --command='df -h | grep -E "Filesystem|/jenkins"' 2>/dev/null
  echo ""
  
  echo "Refreshing in 30 seconds... (Ctrl+C to exit)"
  sleep 30
done
```

Save as `monitor-dashboard.sh` and run: `bash monitor-dashboard.sh`

---

## Contact Information

- **GCP Console**: https://console.cloud.google.com
- **Project**: core-it-infra-prod
- **Region**: us-central1
- **Zone**: us-central1-a

---

## Checklist for New Issues

When encountering a new issue, check in this order:

- [ ] Is the VM running?
- [ ] Is Jenkins service active?
- [ ] Are firewall rules correct?
- [ ] Is the load balancer healthy?
- [ ] Does DNS resolve?
- [ ] Are IAP permissions set?
- [ ] Is disk space available?
- [ ] Are logs showing errors?
- [ ] Is network connectivity working?
- [ ] Are all APIs enabled?

---

**Last Updated**: February 13, 2026  
**Version**: 1.0
