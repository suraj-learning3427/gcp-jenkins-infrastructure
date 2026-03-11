################################################################################
## Jenkins VM Outputs
################################################################################

output "jenkins_vm_name" {
  description = "Name of the Jenkins VM instance"
  value       = google_compute_instance.jenkins_vm.name
}

output "jenkins_vm_id" {
  description = "ID of the Jenkins VM instance"
  value       = google_compute_instance.jenkins_vm.id
}

output "jenkins_vm_internal_ip" {
  description = "Internal IP address of the Jenkins VM"
  value       = google_compute_instance.jenkins_vm.network_interface[0].network_ip
}

output "jenkins_vm_zone" {
  description = "Zone of the Jenkins VM"
  value       = google_compute_instance.jenkins_vm.zone
}

output "jenkins_data_disk_name" {
  description = "Name of the Jenkins data disk"
  value       = google_compute_disk.jenkins_data_disk.name
}

output "jenkins_data_disk_size" {
  description = "Size of the Jenkins data disk in GB"
  value       = google_compute_disk.jenkins_data_disk.size
}

output "jenkins_access_info" {
  description = "Information to access Jenkins"
  value       = "Jenkins is installed on ${google_compute_instance.jenkins_vm.name} at http://${google_compute_instance.jenkins_vm.network_interface[0].network_ip}. Data is stored on the 20GB data disk mounted at /jenkins"
}

output "jenkins_initial_password_command" {
  description = "Command to retrieve Jenkins initial admin password"
  value       = "gcloud compute ssh ${google_compute_instance.jenkins_vm.name} --project=${var.project_id} --zone=${var.zone} --tunnel-through-iap --command='sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword'"
}
