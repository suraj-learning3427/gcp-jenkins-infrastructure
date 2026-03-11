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
  description = "Name of the Windows VM instance"
  default     = "windows-test-server"
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
  default     = 50
}

variable "windows_image" {
  type        = string
  description = "Windows Server image to use"
  default     = "windows-cloud/windows-2022"
}
