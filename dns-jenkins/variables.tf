################################################################################
## Project Configuration
################################################################################

variable "project_id" {
  type        = string
  description = "GCP project ID where DNS resources will be created"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

################################################################################
## DNS Configuration
################################################################################

variable "jenkins_lb_ip" {
  type        = string
  description = "Internal IP address of Jenkins load balancer"
  default     = "10.10.10.50"
}
