provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable Cloud DNS API
resource "google_project_service" "dns_api" {
  project = var.project_id
  service = "dns.googleapis.com"
  
  disable_on_destroy = false
}

# Data source to reference existing VPC
data "google_compute_network" "vpc_spoke" {
  project = var.project_id
  name    = "vpc-spoke"
}

# Create Private DNS Zone for internal domain
resource "google_dns_managed_zone" "jenkins_private_zone" {
  project     = var.project_id
  name        = "jenkins-private-zone"
  dns_name    = "learningmyway.space."
  description = "Private DNS zone for internal Jenkins access"
  visibility  = "private"
  
  private_visibility_config {
    networks {
      network_url = data.google_compute_network.vpc_spoke.id
    }
  }
  
  depends_on = [google_project_service.dns_api]
}

# Create A record for Jenkins hostname pointing to Load Balancer IP
resource "google_dns_record_set" "jenkins_a_record" {
  project      = var.project_id
  name         = "jenkins.np.${google_dns_managed_zone.jenkins_private_zone.dns_name}"
  managed_zone = google_dns_managed_zone.jenkins_private_zone.name
  type         = "A"
  ttl          = 300
  
  rrdatas = [var.jenkins_lb_ip]
}

# Optional: Create CNAME for www if needed
resource "google_dns_record_set" "jenkins_cname" {
  project      = var.project_id
  name         = "www.jenkins.np.${google_dns_managed_zone.jenkins_private_zone.dns_name}"
  managed_zone = google_dns_managed_zone.jenkins_private_zone.name
  type         = "CNAME"
  ttl          = 300
  
  rrdatas = ["jenkins.np.${google_dns_managed_zone.jenkins_private_zone.dns_name}"]
}
