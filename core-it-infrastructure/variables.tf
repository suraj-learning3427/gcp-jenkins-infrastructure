################################################################################
## Google Cloud Project Configuration
################################################################################

variable "new_project_id" {
  type        = string
  description = "New project ID to create (e.g., core-it-infra-prod)"
}

variable "billing_account" {
  type        = string
  description = "Billing account ID to associate with the new project"
}

variable "region" {
  type        = string
  description = "GCP region to deploy resources"
  default     = "us-central1"
}

################################################################################
## Network Configuration
################################################################################

variable "subnet_cidr" {
  type        = string
  description = "CIDR range for the VPC subnet"
  default     = "10.10.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "The subnet_cidr must be a valid CIDR block."
  }
}
