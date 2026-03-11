################################################################################
## Project Configuration
################################################################################

variable "project_id" {
  type        = string
  description = "GCP project ID where resources will be created"
}

variable "region" {
  type        = string
  description = "GCP region to deploy resources"
  default     = "us-central1"
}

################################################################################
## VM Configuration
################################################################################

variable "vm_name" {
  type        = string
  description = "Name of the VM instance"
  default     = "jenkins-server"
}

variable "machine_type" {
  type        = string
  description = "Machine type for the VM instance"
  default     = "e2-standard-2"
}

variable "zone" {
  type        = string
  description = "Zone to deploy the VM instance"
  default     = "us-central1-a"
}

variable "boot_disk_size" {
  type        = number
  description = "Size of the boot disk in GB"
  default     = 20
}

variable "data_disk_size" {
  type        = number
  description = "Size of the data disk in GB"
  default     = 20
}
