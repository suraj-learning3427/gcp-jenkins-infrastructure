# Networkingglobal - VPC Hub Infrastructure

Terraform configuration for Networkingglobal GCP VPC Hub deployment.

## Resources

- **VPC**: vpc-hub
- **Subnet**: subnet-vpn (20.20.0.0/16) in us-central1
- **Firewall**: IAP SSH access (TCP:22 from 35.235.240.0/20)
- **Firewall**: WireGuard VPN (UDP:51820)

## Deployment

1. Configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your project ID
   ```

2. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Clean Up

```bash
terraform destroy
```
