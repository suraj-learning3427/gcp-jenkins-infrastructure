terraform {
  required_version = ">= 1.0"
  
  backend "gcs" {
    bucket = "gcp-learning-hub"
    prefix = "terraform/state/windows-test-vm"
  }
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
