provider "google" {
  region  = var.region
}

# Create new GCP project
resource "google_project" "core_it_infrastructure" {
  name            = "core-it-infrastructure"
  project_id      = var.new_project_id
  billing_account = var.billing_account
}

# Enable required Google Cloud APIs
resource "google_project_service" "compute_api" {
  project = google_project.core_it_infrastructure.project_id
  service = "compute.googleapis.com"
  
  disable_on_destroy = false
}

# Create the VPC network named "vpc-spoke"
resource "google_compute_network" "vpc_spoke" {
  project                 = google_project.core_it_infrastructure.project_id
  name                    = "vpc-spoke"
  auto_create_subnetworks = false
  
  depends_on = [google_project_service.compute_api]
}

# Create subnet named "subnet-jenkins" with CIDR 10.10.0.0/16
resource "google_compute_subnetwork" "subnet_jenkins" {
  project = google_project.core_it_infrastructure.project_id

  name = "subnet-jenkins"

  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_spoke.id

  private_ip_google_access = true
}

# Create Proxy-only subnet for Internal HTTPS Load Balancer
resource "google_compute_subnetwork" "proxy_only_subnet" {
  project = google_project.core_it_infrastructure.project_id
  
  name          = "proxy-only-subnet"
  ip_cidr_range = "10.129.0.0/23"
  region        = "us-central1"
  network       = google_compute_network.vpc_spoke.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# Firewall rule to allow IAP (Identity-Aware Proxy) access
resource "google_compute_firewall" "allow_iap" {
  project = google_project.core_it_infrastructure.project_id
  name    = "allow-iap-ssh"
  network = google_compute_network.vpc_spoke.name
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  source_ranges = ["35.235.240.0/20"]
  
  description = "Allow SSH access from Google Cloud IAP"
}

# Firewall rule to allow Hub traffic
resource "google_compute_firewall" "allow_hub_traffic" {
  project = google_project.core_it_infrastructure.project_id
  name    = "allow-hub-traffic"
  network = google_compute_network.vpc_spoke.name
  
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  
  source_ranges = ["20.20.0.0/16"]
  
  description = "Allow HTTPS traffic from VPC Hub"
}

# Firewall rule to allow Internal Load Balancer traffic from proxy subnet
resource "google_compute_firewall" "allow_ilb_proxy_traffic" {
  project = google_project.core_it_infrastructure.project_id
  name    = "allow-ilb-proxy-traffic"
  network = google_compute_network.vpc_spoke.name
  
  allow {
    protocol = "tcp"
    ports    = ["8080", "80"]
  }
  
  source_ranges = ["10.129.0.0/23"]
  
  description = "Allow traffic from Internal Load Balancer proxy subnet to backends on ports 8080 and 80"
}

# VPC Peering from Spoke to Hub
resource "google_compute_network_peering" "spoke_to_hub" {
  name         = "vpc-spoke-to-vpc-hub"
  network      = google_compute_network.vpc_spoke.self_link
  peer_network = "projects/networkingglobal-prod/global/networks/vpc-hub"
  
  export_custom_routes = true
  import_custom_routes = true
}
