output "dns_zone_name" {
  description = "Name of the DNS managed zone"
  value       = google_dns_managed_zone.jenkins_private_zone.name
}

output "dns_zone_dns_name" {
  description = "DNS name of the managed zone"
  value       = google_dns_managed_zone.jenkins_private_zone.dns_name
}

output "jenkins_fqdn" {
  description = "Fully qualified domain name for Jenkins"
  value       = trimsuffix(google_dns_record_set.jenkins_a_record.name, ".")
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "https://${trimsuffix(google_dns_record_set.jenkins_a_record.name, ".")}"
}

output "dns_name_servers" {
  description = "Name servers for the DNS zone"
  value       = google_dns_managed_zone.jenkins_private_zone.name_servers
}
