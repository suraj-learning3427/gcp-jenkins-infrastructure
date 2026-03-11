# core-it-infrastructure - VPC Spoke Infrastructure

Terraform configuration for core-it-infrastructure GCP VPC Spoke deployment.

## Resources

- **Project**: core-it-infrastructure
- **VPC**: vpc-spoke
- **Subnet**: subnet-jenkins (10.10.0.0/16) in us-central1
- **Firewall**: IAP SSH access (TCP:22 from 35.235.240.0/20)
- **Firewall**: Hub traffic (TCP:443 from 20.20.0.0/16)

## Deployment

1. Initialize and apply:
   ```bash
   cd core-it-infrastructure
   terraform init
   terraform plan
   terraform apply
   ```

## Clean Up

```bash
terraform destroy
```
