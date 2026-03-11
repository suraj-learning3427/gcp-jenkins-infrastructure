variable "project_id" {
  description = "GCP Project ID for Terraform state"
  type        = string
}

variable "hub_project_id" {
  description = "GCP Project ID where vpc-hub is located"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "dns_forwarder_ip" {
  description = "Static internal IP for DNS forwarder"
  type        = string
  default     = "20.20.0.100"
}
