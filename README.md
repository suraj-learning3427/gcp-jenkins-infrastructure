# GCP Learning Hub - Jenkins Infrastructure POC

Complete Infrastructure as Code (IaC) solution for deploying a secure Jenkins CI/CD server on Google Cloud Platform using Terraform.

## 🎯 Project Overview

This repository contains a production-ready Jenkins deployment on GCP featuring:

- **Secure Internal Access**: Jenkins accessible only via internal network
- **HTTPS Encryption**: SSL/TLS with internal HTTPS load balancer
- **Private DNS**: Custom DNS zone for hostname-based access
- **Hub-Spoke Architecture**: Scalable multi-project network design
- **IAP Security**: Identity-Aware Proxy for secure access
- **Complete Automation**: Terraform Infrastructure as Code

## 📚 Documentation

### Quick Start Guides
- **[DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md)** - Step-by-step deployment checklist with architecture diagrams
- **[TROUBLESHOOTING-QUICK-GUIDE.md](TROUBLESHOOTING-QUICK-GUIDE.md)** - Quick fixes for common issues
- **[COMPLETE-DOCUMENTATION.md](COMPLETE-DOCUMENTATION.md)** - Comprehensive documentation (130+ pages)

### Component-Specific Docs
Each component directory has its own README:
- [Networkingglobal/README.md](Networkingglobal/README.md) - Hub VPC
- [core-it-infrastructure/README.md](core-it-infrastructure/README.md) - Spoke VPC
- [jenkins-vm/README.md](jenkins-vm/README.md) - Jenkins server
- [jenkins-ilb/README.md](jenkins-ilb/README.md) - Internal load balancer
- [dns-jenkins/README.md](dns-jenkins/README.md) - Private DNS
- [windows-test-vm/README.md](windows-test-vm/README.md) - Test VM

## 🏗️ Architecture

```
External Users → VPN Gateway (Hub VPC)
                      ↓
              VPC Peering
                      ↓
            Spoke VPC (10.10.0.0/16)
                      ↓
    DNS: jenkins.np.learningmyway.space
                      ↓
    Internal HTTPS LB (10.10.10.50:443)
                      ↓
         Jenkins Server (Rocky Linux 9)
```

### Projects
- **networkingglobal-prod**: Hub VPC with VPN gateway
- **core-it-infra-prod**: Spoke VPC with Jenkins infrastructure

### Network Design
- **Hub VPC**: 20.20.0.0/16 (VPN and external connectivity)
- **Spoke VPC**: 10.10.0.0/16 (Application workloads)
- **Proxy Subnet**: 10.129.0.0/23 (Required for internal LB)

## 🚀 Quick Start

### Prerequisites
```bash
# Install tools
gcloud --version
terraform --version

# Authenticate
gcloud auth login
gcloud auth application-default login
gcloud config set project core-it-infra-prod
```

### Generate SSL Certificates
```bash
mkdir -p cert && cd cert
openssl genrsa -out jenkins.key 2048
openssl req -new -x509 -key jenkins.key -out fullchain.pem -days 365 \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=jenkins.np.learningmyway.space"
openssl req -new -x509 -key jenkins.key -out root-ca.crt -days 365 \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=Root CA"
cd ..
```

### Enable Required APIs
```bash
# Hub project
gcloud services enable compute.googleapis.com servicenetworking.googleapis.com \
  --project=networkingglobal-prod

# Spoke project
gcloud services enable compute.googleapis.com dns.googleapis.com \
  servicenetworking.googleapis.com iap.googleapis.com \
  --project=core-it-infra-prod
```

### Deploy Infrastructure

**Option 1: Use Deployment Checklist**
```bash
# Follow step-by-step guide
cat DEPLOYMENT-CHECKLIST.md
```

**Option 2: Quick Deploy Script**
```bash
# 1. Deploy Hub VPC
cd Networkingglobal && terraform init && terraform apply -auto-approve && cd ..

# 2. Deploy Spoke VPC
cd core-it-infrastructure && terraform init && terraform apply -auto-approve && cd ..

# 3. Configure VPC Peering
gcloud compute networks peerings create spoke-to-hub \
  --network=vpc-spoke --peer-network=vpc-hub \
  --peer-project=networkingglobal-prod --project=core-it-infra-prod

gcloud compute networks peerings create hub-to-spoke \
  --network=vpc-hub --peer-network=vpc-spoke \
  --peer-project=core-it-infra-prod --project=networkingglobal-prod

# 4. Create Proxy-Only Subnet
gcloud compute networks subnets create proxy-only-subnet \
  --purpose=REGIONAL_MANAGED_PROXY --role=ACTIVE \
  --region=us-central1 --network=vpc-spoke \
  --range=10.129.0.0/23 --project=core-it-infra-prod

# 5. Deploy Jenkins VM
cd jenkins-vm && terraform init && terraform apply -auto-approve && cd ..

# Wait 10 minutes for Jenkins installation
sleep 600

# 6. Configure Firewall for Load Balancer
gcloud compute firewall-rules create allow-ilb-to-jenkins \
  --network=vpc-spoke --action=allow --direction=ingress \
  --source-ranges=10.129.0.0/23,35.191.0.0/16,130.211.0.0/22 \
  --target-tags=jenkins-server --rules=tcp:8080,tcp:80 \
  --project=core-it-infra-prod

# 7. Deploy Load Balancer
cd jenkins-ilb && terraform init && terraform apply -auto-approve && cd ..

# 8. Deploy DNS
cd dns-jenkins && terraform init && terraform apply -auto-approve && cd ..

# Wait for DNS propagation
sleep 300

echo "✅ Deployment complete!"
echo "Access Jenkins at: https://jenkins.np.learningmyway.space"
```

**Total deployment time**: ~40-50 minutes

## 🔑 Access Jenkins

### Method 1: SSH Tunnel (Recommended)
```bash
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  -- -L 8080:localhost:8080

# Open browser: http://localhost:8080
```

### Method 2: Via Load Balancer (From VPC)
```bash
# From Windows test VM or any VM in VPC
https://jenkins.np.learningmyway.space
# Or: https://10.10.10.50
```

### Get Initial Admin Password
```bash
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword'
```

## 📁 Repository Structure

```
gcp-learning-hub/
├── cert/                           # SSL certificates
│   ├── fullchain.pem
│   ├── jenkins.key
│   └── root-ca.crt
├── Networkingglobal/              # Hub VPC (20.20.0.0/16)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── README.md
├── core-it-infrastructure/        # Spoke VPC (10.10.0.0/16)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── README.md
├── jenkins-vm/                    # Jenkins server (Rocky Linux 9)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   ├── setup-jenkins-final.sh
│   ├── install-jenkins.sh
│   └── README.md
├── jenkins-ilb/                   # Internal HTTPS load balancer
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── README.md
├── dns-jenkins/                   # Private DNS zone
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   ├── install-ca-cert.sh
│   └── README.md
├── windows-test-vm/               # Windows test server (optional)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── README.md
├── terraform-google-gateway/      # Firezone VPN gateway (optional)
│   └── ...
├── COMPLETE-DOCUMENTATION.md      # Full documentation
├── TROUBLESHOOTING-QUICK-GUIDE.md # Quick troubleshooting
├── DEPLOYMENT-CHECKLIST.md        # Deployment guide
└── README.md                      # This file
```

## 🔍 Health Check

Run this command to check all components:

```bash
#!/bin/bash
echo "=== Jenkins Infrastructure Health Check ==="

# VM Status
echo "VM: $(gcloud compute instances describe jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod \
  --format='value(status)')"

# Jenkins Service
echo "Service: $(gcloud compute ssh jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod \
  --tunnel-through-iap --command='sudo systemctl is-active jenkins')"

# Load Balancer
echo "Load Balancer:"
gcloud compute backend-services get-health jenkins-backend-service \
  --region=us-central1 --project=core-it-infra-prod | grep healthState

# DNS
echo "DNS:"
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='nslookup jenkins.np.learningmyway.space' | grep Address
```

Expected output:
```
VM: RUNNING
Service: active
Load Balancer: healthState: HEALTHY
DNS: Address: 10.10.10.50
```

## 🔧 Common Operations

### Restart Jenkins
```bash
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl restart jenkins'
```

### View Logs
```bash
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo journalctl -u jenkins -n 100'
```

### Create Backup
```bash
gcloud compute disks snapshot jenkins-data-disk \
  --zone=us-central1-a --project=core-it-infra-prod \
  --snapshot-names=jenkins-backup-$(date +%Y%m%d)
```

### Scale Up VM
```bash
gcloud compute instances stop jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod

gcloud compute instances set-machine-type jenkins-server \
  --machine-type=e2-standard-4 \
  --zone=us-central1-a --project=core-it-infra-prod

gcloud compute instances start jenkins-server \
  --zone=us-central1-a --project=core-it-infra-prod
```

## ⚠️ Troubleshooting

### Jenkins Service Not Starting
```bash
# Check service status
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemctl status jenkins'

# View logs
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo journalctl -u jenkins -n 50'

# Fix common issues
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo chown -R jenkins:jenkins /jenkins/jenkins_home && sudo systemctl restart jenkins'
```

### Load Balancer Unhealthy
```bash
# Check backend health
gcloud compute backend-services get-health jenkins-backend-service \
  --region=us-central1 --project=core-it-infra-prod

# Verify firewall rules
gcloud compute firewall-rules list --filter="name~health OR name~ilb" \
  --project=core-it-infra-prod

# Test endpoint
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='curl -I http://localhost:8080/login'
```

### DNS Not Resolving
```bash
# Check DNS zone
gcloud dns managed-zones describe jenkins-private-zone \
  --project=core-it-infra-prod

# Check DNS records
gcloud dns record-sets list --zone=jenkins-private-zone \
  --project=core-it-infra-prod

# Clear cache and test
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --project=core-it-infra-prod --tunnel-through-iap \
  --command='sudo systemd-resolve --flush-caches && nslookup jenkins.np.learningmyway.space'
```

**For detailed troubleshooting**: See [TROUBLESHOOTING-QUICK-GUIDE.md](TROUBLESHOOTING-QUICK-GUIDE.md)

## 💰 Cost Estimate

Approximate monthly costs (us-central1):

| Resource | Cost/Month |
|----------|------------|
| Jenkins VM (e2-standard-2) | $50 |
| Persistent Disks (40 GB) | $7 |
| Internal Load Balancer | $20 |
| Network Egress | Variable |
| DNS Zone | $0.25 |
| **Total** | **~$77-100** |

### Cost Optimization
- Stop VMs when not in use
- Use committed use discounts
- Delete test resources (Windows VM)
- Clean up old snapshots
- Monitor and optimize disk usage

## 🧹 Cleanup

### Destroy All Resources
```bash
# In reverse order of creation
cd windows-test-vm && terraform destroy -auto-approve && cd ..
cd dns-jenkins && terraform destroy -auto-approve && cd ..
cd jenkins-ilb && terraform destroy -auto-approve && cd ..
cd jenkins-vm && terraform destroy -auto-approve && cd ..
cd core-it-infrastructure && terraform destroy -auto-approve && cd ..
cd Networkingglobal && terraform destroy -auto-approve && cd ..

# Delete VPC peering
gcloud compute networks peerings delete spoke-to-hub \
  --network=vpc-spoke --project=core-it-infra-prod
gcloud compute networks peerings delete hub-to-spoke \
  --network=vpc-hub --project=networkingglobal-prod

# Delete proxy subnet
gcloud compute networks subnets delete proxy-only-subnet \
  --region=us-central1 --project=core-it-infra-prod

# Delete firewall rules (if created manually)
gcloud compute firewall-rules delete allow-ilb-to-jenkins \
  --project=core-it-infra-prod
```

## 📋 Features

### Security
- ✅ No external IPs on VMs
- ✅ IAP for SSH/RDP access
- ✅ HTTPS with SSL certificates
- ✅ Restrictive firewall rules
- ✅ Private DNS zones
- ✅ VPC peering for network isolation

### Scalability
- ✅ Hub-spoke network architecture
- ✅ Load balancer ready for multiple backends
- ✅ Separate data disk for easy scaling
- ✅ Regional deployment

### Reliability
- ✅ Health checks on load balancer
- ✅ Automated startup scripts
- ✅ Persistent data disk
- ✅ Snapshot-ready for backups

### Monitoring
- ✅ GCP console monitoring
- ✅ Service logs via journalctl
- ✅ Load balancer metrics
- ✅ Health check status

## 🎓 Learning Objectives

This POC demonstrates:
1. **Terraform IaC**: Infrastructure as Code best practices
2. **GCP Networking**: VPC, subnets, peering, firewalls
3. **Load Balancing**: Internal HTTPS load balancers
4. **DNS Management**: Private Cloud DNS zones
5. **Security**: IAP, SSL/TLS, network segmentation
6. **Linux Administration**: Rocky Linux, systemd, disk management
7. **CI/CD**: Jenkins deployment and configuration

## 📖 Additional Resources

- [GCP Internal Load Balancer Docs](https://cloud.google.com/load-balancing/docs/l7-internal)
- [GCP Cloud DNS Docs](https://cloud.google.com/dns/docs)
- [GCP VPC Peering Docs](https://cloud.google.com/vpc/docs/vpc-peering)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Rocky Linux Documentation](https://docs.rockylinux.org/)

## 🤝 Support

For issues or questions:
1. Check [TROUBLESHOOTING-QUICK-GUIDE.md](TROUBLESHOOTING-QUICK-GUIDE.md)
2. Review [COMPLETE-DOCUMENTATION.md](COMPLETE-DOCUMENTATION.md)
3. Check GCP logs and monitoring
4. Verify prerequisites are met

## 📝 Notes

### Self-Signed Certificates
This POC uses self-signed SSL certificates for testing. For production:
- Use Google-managed certificates
- Or obtain certificates from a trusted CA

### Production Considerations
- Enable Cloud Armor for WAF protection
- Set up Cloud Monitoring with alerts
- Enable VPC Flow Logs
- Implement automated backups
- Deploy multi-region for HA
- Use Cloud NAT for outbound internet
- Implement disaster recovery plan

### Known Limitations
- Single Jenkins instance (no HA)
- Self-signed certificates require manual trust
- Single region deployment
- Manual DNS management for external access

## 📊 Project Status

- ✅ Network infrastructure complete
- ✅ Jenkins VM deployment complete
- ✅ Load balancer configuration complete
- ✅ Private DNS setup complete
- ✅ Documentation complete
- ✅ Troubleshooting guides complete

## 🔄 Version History

- **v1.0** (2026-02-13): Initial release with complete documentation

---

## Quick Commands Reference

```bash
# Check everything
gcloud compute instances list --project=core-it-infra-prod
gcloud compute backend-services get-health jenkins-backend-service --region=us-central1 --project=core-it-infra-prod

# Access Jenkins
gcloud compute ssh jenkins-server --zone=us-central1-a --project=core-it-infra-prod --tunnel-through-iap -- -L 8080:localhost:8080

# Get password
gcloud compute ssh jenkins-server --zone=us-central1-a --project=core-it-infra-prod --tunnel-through-iap --command='sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword'

# Restart  
gcloud compute ssh jenkins-server --zone=us-central1-a --project=core-it-infra-prod --tunnel-through-iap --command='sudo systemctl restart jenkins'

# Backup
gcloud compute disks snapshot jenkins-data-disk --zone=us-central1-a --project=core-it-infra-prod --snapshot-names=backup-$(date +%Y%m%d)

# Test DNS
gcloud compute ssh jenkins-server --zone=us-central1-a --project=core-it-infra-prod --tunnel-through-iap --command='nslookup jenkins.np.learningmyway.space'
```

---

**Project**: GCP Jenkins Infrastructure POC  
**Organization**: Learning Hub  
**Last Updated**: February 13, 2026  
**License**: MIT  
**Author**: Infrastructure Team
