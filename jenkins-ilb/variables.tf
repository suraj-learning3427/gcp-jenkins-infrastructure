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

variable "zone" {
  type        = string
  description = "Zone where Jenkins server is deployed"
  default     = "us-central1-a"
}
