# Jenkins Internal HTTPS Load Balancer

This Terraform configuration creates an Internal HTTPS Load Balancer for the Jenkins server in the `core-it-infrastructure` project.

## Components

### 1. Instance Group
- **Name**: `jenkins-instance-group`
- **Zone**: `us-central1-a`
- **Instances**: `jenkins-server`
- **Named Ports**: 
  - `http`: 8080
  - `http-alt`: 80

### 2. Health Check
- **Name**: `jenkins-health-check`
- **Protocol**: HTTP
- **Port**: 8080
- **Path**: `/login`
- **Check Interval**: 10 seconds
- **Timeout**: 5 seconds

### 3. Backend Service
- **Name**: `jenkins-backend-service`
- **Type**: Regional Backend Service
- **Protocol**: HTTP
- **Load Balancing Scheme**: INTERNAL_MANAGED
- **Backend**: Jenkins Instance Group

### 4. SSL Certificate
- **Name**: `jenkins-ssl-certificate`
- **Type**: Regional SSL Certificate
- **Private Key**: `../cert/jenkins.key`
- **Certificate**: `../cert/fullchain.pem`

### 5. Frontend (Forwarding Rule)
- **Name**: `jenkins-forwarding-rule`
- **IP Address**: 10.10.10.50 (static internal IP)
- **Protocol**: HTTPS
- **Port**: 443
- **Load Balancing Scheme**: INTERNAL_MANAGED

## Prerequisites

1. Jenkins server must be running in `core-it-infrastructure` project
2. VPC `vpc-spoke` must exist
3. Subnet `subnet-jenkins` must exist
4. SSL certificates must be present in `../cert/` directory:
   - `jenkins.key` (private key)
   - `fullchain.pem` (certificate chain)
5. Proxy-only subnet (10.129.0.0/23) must be configured in the VPC
6. Firewall rules must allow traffic from proxy subnet (10.129.0.0/23) to backends on ports 8080 and 80

## Deployment

1. Initialize Terraform:
   ```bash
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

## Access

After deployment, Jenkins will be accessible at:
```
https://10.10.10.50
```

Use the load balancer IP from within the VPC or via VPN/peered networks.

## Architecture

```
Internet/VPN → VPC Spoke → ILB (10.10.10.50:443) → Backend Service → Instance Group → Jenkins Server (port 8080)
                                     ↓
                              Health Check (8080/login)
```

## Notes

- This is an **Internal** load balancer, accessible only from within the VPC or peered networks
- The load balancer terminates HTTPS and forwards HTTP traffic to Jenkins on port 8080
- Health checks ensure Jenkins is healthy before routing traffic
- The static IP (10.10.10.50) is reserved in the jenkins subnet
