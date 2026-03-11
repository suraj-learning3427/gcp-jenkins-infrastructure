provider "google" {
  project = var.project_id
  region  = var.region
}

# Data source to reference existing VPC
data "google_compute_network" "vpc_spoke" {
  project = var.project_id
  name    = "vpc-spoke"
}

# Data source to reference existing subnet
data "google_compute_subnetwork" "subnet_jenkins" {
  project = var.project_id
  name    = "subnet-jenkins"
  region  = var.region
}

# Data source to reference existing Jenkins VM instance
data "google_compute_instance" "jenkins_server" {
  project = var.project_id
  name    = "jenkins-server"
  zone    = var.zone
}

# Firewall rule to allow Google Cloud health check probes
resource "google_compute_firewall" "allow_health_check" {
  project = var.project_id
  name    = "allow-health-check-probes"
  network = data.google_compute_network.vpc_spoke.name
  
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["jenkins-server"]
  
  description = "Allow Google Cloud health check probes to Jenkins"
}

# Create instance group for Jenkins server
resource "google_compute_instance_group" "jenkins_instance_group" {
  project   = var.project_id
  name      = "jenkins-instance-group"
  zone      = var.zone
  
  instances = [
    data.google_compute_instance.jenkins_server.self_link
  ]
  
  named_port {
    name = "http"
    port = 80
  }
}

# Health check for Jenkins on port 80
resource "google_compute_health_check" "jenkins_health_check" {
  project = var.project_id
  name    = "jenkins-health-check"
  
  timeout_sec        = 5
  check_interval_sec = 10
  healthy_threshold  = 2
  unhealthy_threshold = 3
  
  http_health_check {
    port         = 80
    request_path = "/login"
  }
}

# SSL Certificate for HTTPS Load Balancer
resource "google_compute_region_ssl_certificate" "jenkins_ssl_cert" {
  project     = var.project_id
  region      = var.region
  name_prefix = "jenkins-ssl-certificate-"
  private_key = file("${path.module}/../cert/jenkins.key")
  certificate = file("${path.module}/../cert/fullchain.pem")
  
  lifecycle {
    create_before_destroy = true
  }
}

# Backend Service for Internal Load Balancer
resource "google_compute_region_backend_service" "jenkins_backend_service" {
  project       = var.project_id
  region        = var.region
  name          = "jenkins-backend-service"
  protocol      = "HTTP"
  timeout_sec   = 30
  health_checks = [google_compute_health_check.jenkins_health_check.id]
  
  backend {
    group           = google_compute_instance_group.jenkins_instance_group.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
  
  load_balancing_scheme = "INTERNAL_MANAGED"
}

# Reserve static internal IP address
resource "google_compute_address" "jenkins_ilb_ip" {
  project      = var.project_id
  name         = "jenkins-ilb-ip"
  region       = var.region
  subnetwork   = data.google_compute_subnetwork.subnet_jenkins.id
  address_type = "INTERNAL"
  address      = "10.10.10.50"
  purpose      = "GCE_ENDPOINT"
}

# URL Map for the load balancer
resource "google_compute_region_url_map" "jenkins_url_map" {
  project         = var.project_id
  region          = var.region
  name            = "jenkins-url-map"
  default_service = google_compute_region_backend_service.jenkins_backend_service.id
}

# HTTPS Target Proxy
resource "google_compute_region_target_https_proxy" "jenkins_https_proxy" {
  project = var.project_id
  region  = var.region
  name    = "jenkins-https-proxy"
  url_map = google_compute_region_url_map.jenkins_url_map.id
  
  ssl_certificates = [
    google_compute_region_ssl_certificate.jenkins_ssl_cert.id
  ]
}

# Forwarding Rule (Frontend)
resource "google_compute_forwarding_rule" "jenkins_forwarding_rule" {
  project               = var.project_id
  name                  = "jenkins-forwarding-rule"
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.jenkins_https_proxy.id
  network               = data.google_compute_network.vpc_spoke.id
  subnetwork            = data.google_compute_subnetwork.subnet_jenkins.id
  ip_address            = google_compute_address.jenkins_ilb_ip.id
  
  network_tier = "PREMIUM"
}
