output "load_balancer_ip" {
  description = "Internal IP address of the HTTPS load balancer"
  value       = google_compute_address.jenkins_ilb_ip.address
}

output "instance_group_name" {
  description = "Name of the Jenkins instance group"
  value       = google_compute_instance_group.jenkins_instance_group.name
}

output "backend_service_name" {
  description = "Name of the backend service"
  value       = google_compute_region_backend_service.jenkins_backend_service.name
}

output "health_check_name" {
  description = "Name of the health check"
  value       = google_compute_health_check.jenkins_health_check.name
}

output "forwarding_rule_name" {
  description = "Name of the forwarding rule"
  value       = google_compute_forwarding_rule.jenkins_forwarding_rule.name
}

output "access_url" {
  description = "URL to access Jenkins via the load balancer"
  value       = "https://${google_compute_address.jenkins_ilb_ip.address}"
}
