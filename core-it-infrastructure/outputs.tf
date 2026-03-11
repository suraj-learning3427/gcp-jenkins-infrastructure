################################################################################
## VPC Outputs
################################################################################

output "vpc_name" {
  description = "The name of the VPC"
  value       = google_compute_network.vpc_spoke.name
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.vpc_spoke.id
}

output "vpc_self_link" {
  description = "The URI of the VPC"
  value       = google_compute_network.vpc_spoke.self_link
}

################################################################################
## Subnet Outputs
################################################################################

output "subnet_name" {
  description = "The name of the subnet"
  value       = google_compute_subnetwork.subnet_jenkins.name
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = google_compute_subnetwork.subnet_jenkins.id
}

output "subnet_ip_cidr_range" {
  description = "The CIDR range of the subnet"
  value       = google_compute_subnetwork.subnet_jenkins.ip_cidr_range
}

output "subnet_region" {
  description = "The region of the subnet"
  value       = google_compute_subnetwork.subnet_jenkins.region
}

################################################################################
## Firewall Outputs
################################################################################

output "firewall_iap_name" {
  description = "Name of the IAP firewall rule"
  value       = google_compute_firewall.allow_iap.name
}

output "firewall_hub_traffic_name" {
  description = "Name of the hub traffic firewall rule"
  value       = google_compute_firewall.allow_hub_traffic.name
}

################################################################################
## Project Outputs
################################################################################

output "project_id" {
  description = "The project ID"
  value       = google_project.core_it_infrastructure.project_id
}

output "project_number" {
  description = "The project number"
  value       = google_project.core_it_infrastructure.number
}

################################################################################
## VPC Peering Outputs
################################################################################

output "vpc_peering_spoke_to_hub" {
  description = "VPC peering from spoke to hub"
  value       = google_compute_network_peering.spoke_to_hub.name
}

output "vpc_peering_state" {
  description = "State of the VPC peering connection"
  value       = google_compute_network_peering.spoke_to_hub.state
}
