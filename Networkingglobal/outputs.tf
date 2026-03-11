################################################################################
## VPC Outputs
################################################################################

output "vpc_name" {
  description = "The name of the VPC"
  value       = google_compute_network.vpc_hub.name
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.vpc_hub.id
}

output "vpc_self_link" {
  description = "The URI of the VPC"
  value       = google_compute_network.vpc_hub.self_link
}

################################################################################
## Subnet Outputs
################################################################################

output "subnet_name" {
  description = "The name of the subnet"
  value       = google_compute_subnetwork.subnet_vpn.name
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = google_compute_subnetwork.subnet_vpn.id
}

output "subnet_ip_cidr_range" {
  description = "The CIDR range of the subnet"
  value       = google_compute_subnetwork.subnet_vpn.ip_cidr_range
}

output "subnet_region" {
  description = "The region of the subnet"
  value       = google_compute_subnetwork.subnet_vpn.region
}

################################################################################
## Firewall Outputs
################################################################################

output "firewall_iap_name" {
  description = "Name of the IAP firewall rule"
  value       = google_compute_firewall.allow_iap.name
}

output "firewall_firezone_name" {
  description = "Name of the Firezone/WireGuard firewall rule"
  value       = google_compute_firewall.allow_firezone_udp.name
}

################################################################################
## VPC Peering Outputs
################################################################################

output "vpc_peering_hub_to_spoke" {
  description = "VPC peering from hub to spoke"
  value       = google_compute_network_peering.hub_to_spoke.name
}

output "vpc_peering_state" {
  description = "State of the VPC peering connection"
  value       = google_compute_network_peering.hub_to_spoke.state
}
