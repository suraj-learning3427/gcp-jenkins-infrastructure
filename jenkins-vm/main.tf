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

# Firewall rule to allow Jenkins access
resource "google_compute_firewall" "allow_jenkins" {
  project = var.project_id
  name    = "allow-jenkins-access"
  network = data.google_compute_network.vpc_spoke.name
  
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins-server"]
  
  description = "Allow Jenkins web interface access on port 80"
}

# Data disk for Jenkins
resource "google_compute_disk" "jenkins_data_disk" {
  project = var.project_id
  name    = "jenkins-data-disk"
  type    = "pd-standard"
  zone    = var.zone
  size    = var.data_disk_size
}

# Jenkins VM Instance with Rocky Linux
resource "google_compute_instance" "jenkins_vm" {
  project      = var.project_id
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  
  tags = ["jenkins-server"]
  
  boot_disk {
    initialize_params {
      # Rocky Linux 9 image
      image = "rocky-linux-cloud/rocky-linux-9"
      size  = var.boot_disk_size
      type  = "pd-standard"
    }
  }
  
  attached_disk {
    source      = google_compute_disk.jenkins_data_disk.id
    device_name = "jenkins-data"
  }
  
  network_interface {
    network    = data.google_compute_network.vpc_spoke.id
    subnetwork = data.google_compute_subnetwork.subnet_jenkins.id
  }
  
  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e
    
    # Log all output
    exec > >(tee -a /var/log/startup-script.log)
    exec 2>&1
    
    echo "Starting VM setup..."
    
    # Wait for the data disk to be available
    while [ ! -e /dev/disk/by-id/google-jenkins-data ]; do
      echo "Waiting for data disk..."
      sleep 2
    done
    
    # Format and mount the data disk
    DISK_DEVICE="/dev/disk/by-id/google-jenkins-data"
    MOUNT_POINT="/jenkins"
    
    # Check if the disk is already formatted
    if ! blkid "$DISK_DEVICE"; then
      echo "Formatting data disk..."
      mkfs.ext4 -F "$DISK_DEVICE"
    fi
    
    # Create mount point
    mkdir -p "$MOUNT_POINT"
    
    # Mount the disk
    mount "$DISK_DEVICE" "$MOUNT_POINT"
    
    # Add to fstab for persistent mounting
    UUID=$(blkid -s UUID -o value "$DISK_DEVICE")
    if ! grep -q "$UUID" /etc/fstab; then
      echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
    fi
    
    echo "Data disk mounted at $MOUNT_POINT"
    
    # Update system
    echo "Updating system packages..."
    dnf update -y
    
    # Install Java (required for Jenkins)
    echo "Installing Java..."
    dnf install -y java-17-openjdk java-17-openjdk-devel
    
    # Install Jenkins
    echo "Installing Jenkins..."
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    dnf install -y jenkins
    
    # Configure Jenkins to use the data disk
    echo "Configuring Jenkins..."
    systemctl stop jenkins || true
    
    # Create Jenkins directory on data disk
    mkdir -p "$MOUNT_POINT/jenkins_home"
    chown -R jenkins:jenkins "$MOUNT_POINT/jenkins_home"
    
    # Update Jenkins configuration
    sed -i 's|JENKINS_HOME="/var/lib/jenkins"|JENKINS_HOME="'"$MOUNT_POINT"'/jenkins_home"|' /usr/lib/systemd/system/jenkins.service
    
    # Configure Jenkins to run on port 80
    mkdir -p /etc/systemd/system/jenkins.service.d
    cat > /etc/systemd/system/jenkins.service.d/override.conf <<-CONF
[Service]
Environment="JENKINS_PORT=80"
# Allow binding to privileged ports
AmbientCapabilities=CAP_NET_BIND_SERVICE
CONF
    
    # Give Java permission to bind to privileged ports
    JAVA_PATH=$(readlink -f /usr/bin/java)
    setcap 'cap_net_bind_service=+ep' "$JAVA_PATH"
    
    # Reload systemd and start Jenkins
    systemctl daemon-reload
    systemctl enable jenkins
    systemctl start jenkins
    
    # Open firewall for Jenkins
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --reload
    
    echo "Jenkins installation completed!"
    echo "Jenkins is running on port 80"
    echo "Initial admin password location: $MOUNT_POINT/jenkins_home/secrets/initialAdminPassword"
    
  EOF
  
  depends_on = [google_compute_disk.jenkins_data_disk]
}
