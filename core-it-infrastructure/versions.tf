terraform {
  required_version = ">= 1.0"
  
  backend "gcs" {
    bucket = "gcp-learning-hub"
    prefix = "terraform/state/core-it-infrastructure"
  }
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
