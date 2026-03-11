output "dns_forwarder_ip" {
  description = "IP address of the DNS forwarder to use in Firezone"
  value       = google_compute_instance.dns_forwarder.network_interface[0].network_ip
}

output "dns_forwarder_name" {
  description = "Name of the DNS forwarder VM"
  value       = google_compute_instance.dns_forwarder.name
}

output "firezone_dns_configuration" {
  description = "Add this DNS server IP to Firezone portal"
  value       = "Configure Firezone with DNS server: ${google_compute_instance.dns_forwarder.network_interface[0].network_ip}"
}
