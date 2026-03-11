output "instance_name" {
  description = "Name of the Windows Server instance"
  value       = google_compute_instance.windows_test_vm.name
}

output "instance_internal_ip" {
  description = "Internal IP address of the Windows Server"
  value       = google_compute_instance.windows_test_vm.network_interface[0].network_ip
}

output "instance_zone" {
  description = "Zone where the Windows Server is deployed"
  value       = google_compute_instance.windows_test_vm.zone
}

output "rdp_connection_command" {
  description = "Command to connect via RDP using IAP"
  value       = "gcloud compute start-iap-tunnel ${google_compute_instance.windows_test_vm.name} 3389 --local-host-port=localhost:3389 --zone=${var.zone} --project=${var.project_id}"
}

output "password_reset_command" {
  description = "Command to reset Windows password"
  value       = "gcloud compute reset-windows-password ${google_compute_instance.windows_test_vm.name} --zone=${var.zone} --project=${var.project_id} --user=admin"
}

output "jenkins_test_url" {
  description = "Jenkins URL to test from Windows Server"
  value       = "https://jenkins.np.learningmyway.space"
}
