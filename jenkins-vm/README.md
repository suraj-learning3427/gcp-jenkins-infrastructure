# Jenkins VM with Rocky Linux

This Terraform configuration creates a Jenkins VM with Rocky Linux in the existing `core-it-infrastructure` project.

## Prerequisites

- The `core-it-infrastructure` project must already be created
- The `vpc-spoke` VPC network must exist
- The `subnet-jenkins` subnet must exist

## VM Specifications

- **Name**: jenkins-server
- **OS**: Rocky Linux 9
- **Machine Type**: e2-standard-2
- **Zone**: us-central1-a
- **Boot Disk**: 20 GB (pd-standard)
- **Data Disk**: 20 GB (pd-standard, mounted at `/jenkins`)
- **Network**: Connected to existing `vpc-spoke` and `subnet-jenkins`

## Deployment

### 1. Initialize Terraform
```bash
cd jenkins-vm
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Apply the Configuration
```bash
terraform apply
```

### 4. Get Outputs
```bash
terraform output
terraform output jenkins_vm_internal_ip
```

## Accessing Jenkins

### SSH to VM
```bash
gcloud compute ssh jenkins-server \
  --project=core-it-infra-prod \
  --zone=us-central1-a \
  --tunnel-through-iap
```

### Get Initial Admin Password
```bash
sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword
```

Or use the output command:
```bash
terraform output -raw jenkins_initial_password_command | sh
```

### Access Jenkins UI
Navigate to: `http://<VM_INTERNAL_IP>`

Get the internal IP:
```bash
terraform output jenkins_vm_internal_ip
```

## Configuration Details

### Disks
- **Boot Disk** (`/dev/sda`): 20 GB - Rocky Linux 9 OS
- **Data Disk** (`/dev/sdb`): 20 GB - Jenkins home at `/jenkins/jenkins_home`

### Firewall
- Port 80 is open for Jenkins access
- VM has the `jenkins-server` tag

### Jenkins Configuration
- Jenkins home: `/jenkins/jenkins_home` (on data disk)
- Service: Configured to auto-start on boot
- Startup logs: `/var/log/startup-script.log`

## Customization

### Enable External IP
Uncomment the `access_config {}` block in [main.tf](main.tf):
```hcl
network_interface {
  network    = data.google_compute_network.vpc_spoke.id
  subnetwork = data.google_compute_subnetwork.subnet_jenkins.id
  
  access_config {}  # Uncomment this line
}
```

Then apply:
```bash
terraform apply
```

### Change Machine Type
Edit [terraform.tfvars](terraform.tfvars):
```hcl
machine_type = "e2-standard-4"
```

### Change Disk Sizes
Edit [terraform.tfvars](terraform.tfvars):
```hcl
boot_disk_size = 20
data_disk_size = 50
```

## Troubleshooting

### Check VM Status
```bash
gcloud compute instances describe jenkins-server \
  --project=core-it-infra-prod \
  --zone=us-central1-a
```

### View Startup Script Logs
```bash
gcloud compute ssh jenkins-server \
  --project=core-it-infra-prod \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command='sudo tail -100 /var/log/startup-script.log'
```

### Check Jenkins Service Status
```bash
gcloud compute ssh jenkins-server \
  --project=core-it-infra-prod \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command='sudo systemctl status jenkins'
```

### Verify Data Disk Mount
```bash
gcloud compute ssh jenkins-server \
  --project=core-it-infra-prod \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command='df -h | grep /jenkins'
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Note**: This will delete the VM and both disks, including all Jenkins data.
