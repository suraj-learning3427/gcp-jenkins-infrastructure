provider "google" {
  project = var.project_id
  region  = var.region
}

# Data source to reference existing VPC hub
data "google_compute_network" "vpc_hub" {
  project = var.hub_project_id
  name    = "vpc-hub"
}

# Data source to reference existing subnet
data "google_compute_subnetwork" "subnet_vpn" {
  project = var.hub_project_id
  name    = "subnet-vpn"
  region  = var.region
}

# Firewall rule to allow DNS queries to the forwarder
resource "google_compute_firewall" "allow_dns" {
  project = var.hub_project_id
  name    = "allow-dns-forwarder"
  network = data.google_compute_network.vpc_hub.name
  
  allow {
    protocol = "udp"
    ports    = ["53"]
  }
  
  allow {
    protocol = "tcp"
    ports    = ["53"]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["dns-forwarder"]
  
  description = "Allow DNS queries to DNS forwarder"
}

# DNS Forwarder VM
resource "google_compute_instance" "dns_forwarder" {
  project      = var.hub_project_id
  name         = "dns-forwarder"
  machine_type = "e2-micro"
  zone         = var.zone
  
  tags = ["dns-forwarder"]
  
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 10
      type  = "pd-standard"
    }
  }
  
  network_interface {
    network    = data.google_compute_network.vpc_hub.id
    subnetwork = data.google_compute_subnetwork.subnet_vpn.id
    
    # Reserve a static internal IP for easy reference
    network_ip = var.dns_forwarder_ip
    
    # Add external IP for package installation
    access_config {
      // Ephemeral IP
    }
  }
  
  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    apt-get update
    apt-get install -y dnsmasq dig
    
    # Disable systemd-resolved to free up port 53
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
   
    # Configure dnsmasq using conf.d directory (avoids --local-service flag)
    mkdir -p /etc/dnsmasq.d
    
    # Create learningmyway domain forwarding config
    cat > /etc/dnsmasq.d/learningmyway.conf <<DNSMASQ_CONF
server=/learningmyway.space/169.254.169.254
server=8.8.8.8
server=8.8.4.4
DNSMASQ_CONF
    
    # Create listen config to accept queries from all sources
    cat > /etc/dnsmasq.d/listen.conf <<LISTEN_CONF
listen-address=::,0.0.0.0
bind-interfaces
no-dhcp-interface=
LISTEN_CONF
    
    # Override systemd service to remove --local-service flag
    mkdir -p /etc/systemd/system/dnsmasq.service.d
    cat > /etc/systemd/system/dnsmasq.service.d/override.conf <<OVERRIDE_CONF
[Service]
ExecStart=
ExecStart=/usr/sbin/dnsmasq -k --conf-file=/etc/dnsmasq.conf
OVERRIDE_CONF
    
    # Reload systemd and restart dnsmasq
    systemctl daemon-reload
    systemctl restart dnsmasq
    systemctl enable dnsmasq
    
    echo "DNS forwarder configured successfully!"
    echo "Forwarding *.learningmyway.space to 169.254.169.254"
    echo "DNS server is ready at $(hostname -I | awk '{print $1}')"
  EOF
}
