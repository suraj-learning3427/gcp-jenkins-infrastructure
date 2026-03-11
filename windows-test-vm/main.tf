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

# Firewall rule to allow RDP access via IAP
resource "google_compute_firewall" "allow_iap_rdp" {
  project = var.project_id
  name    = "allow-iap-rdp-windows"
  network = data.google_compute_network.vpc_spoke.name
  
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["windows-test-server"]
  
  description = "Allow RDP access from Google Cloud IAP"
}

# Firewall rule to allow internal communication
resource "google_compute_firewall" "allow_internal_windows" {
  project = var.project_id
  name    = "allow-internal-windows"
  network = data.google_compute_network.vpc_spoke.name
  
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "445", "139"]
  }
  
  allow {
    protocol = "icmp"
  }
  
  source_ranges = ["10.10.0.0/16"]
  target_tags   = ["windows-test-server"]
  
  description = "Allow internal traffic to Windows test server"
}

# Windows Server VM Instance
resource "google_compute_instance" "windows_test_vm" {
  project      = var.project_id
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  
  tags = ["windows-test-server"]
  
  boot_disk {
    initialize_params {
      # Windows Server 2022 Datacenter
      image = var.windows_image
      size  = var.boot_disk_size
      type  = "pd-standard"
    }
  }
  
  network_interface {
    network    = data.google_compute_network.vpc_spoke.id
    subnetwork = data.google_compute_subnetwork.subnet_jenkins.id
    
    # No external IP - access via IAP
    # Uncomment to assign external IP
    # access_config {}
  }
  
  # Windows-specific metadata
  metadata = {
    windows-startup-script-ps1 = <<-EOT
      # Enable Windows Remote Management
      Enable-PSRemoting -Force
      
      # Configure Windows Firewall to allow necessary traffic
      New-NetFirewallRule -DisplayName "Allow Jenkins Access" -Direction Inbound -Protocol TCP -LocalPort 80,443 -Action Allow
      
      # Set timezone
      Set-TimeZone -Id "Central Standard Time"
      
      # Install Chrome for testing (optional)
      Write-Host "Windows Server setup complete"
    EOT
  }
  
  # Allow the instance to be stopped for updates
  allow_stopping_for_update = true
}
