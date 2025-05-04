# Data sources
data "hcloud_image" "ubuntu" {
  name = var.image
  most_recent = true
}

# SSH Key
resource "hcloud_ssh_key" "k3s" {
  name       = "${var.base_name}-key"
  public_key = var.ssh_public_key
}

# Network
resource "hcloud_network" "k3s" {
  name     = "${var.base_name}-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "k3s" {
  network_id   = hcloud_network.k3s.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = "10.0.0.0/24"
}

# Firewall
resource "hcloud_firewall" "k3s" {
  name = "${var.base_name}-firewall"

  # SSH
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS for K3s API
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Allow all internal traffic
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "any"
    source_ips = ["10.0.0.0/16"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "any"
    source_ips = ["10.0.0.0/16"]
  }

  # ICMP (ping)
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

# Master nodes
resource "hcloud_server" "master" {
  count       = var.master_count
  name        = "${var.base_name}-master-${count.index + 1}"
  image       = data.hcloud_image.ubuntu.id
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.k3s.id]
  firewall_ids = [hcloud_firewall.k3s.id]
  
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.k3s.id
  }

  depends_on = [
    hcloud_network_subnet.k3s
  ]

  connection {
    host        = self.ipv4_address
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y python3"
    ]
  }
  
  lifecycle {
    prevent_destroy = false
    
    ignore_changes = [
      image,
      ssh_keys,
      firewall_ids
    ]
  }
}

# Worker nodes
resource "hcloud_server" "worker" {
  count       = var.worker_count
  name        = "${var.base_name}-worker-${count.index + 1}"
  image       = data.hcloud_image.ubuntu.id
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.k3s.id]
  firewall_ids = [hcloud_firewall.k3s.id]
  
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.k3s.id
  }

  depends_on = [
    hcloud_network_subnet.k3s
  ]

  connection {
    host        = self.ipv4_address
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y python3"
    ]
  }
  
  lifecycle {
    prevent_destroy = false
    
    ignore_changes = [
      image,
      ssh_keys,
      firewall_ids
    ]
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl",
    {
      master_nodes = hcloud_server.master.*.ipv4_address
      worker_nodes = hcloud_server.worker.*.ipv4_address
    }
  )
  filename = "${path.module}/../ansible/inventory/hosts.ini"

  depends_on = [
    hcloud_server.master,
    hcloud_server.worker,
  ]
  
  lifecycle {
    replace_triggered_by = []
  }
}