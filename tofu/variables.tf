variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH Public Key"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH Private Key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "location" {
  description = "Hetzner Cloud Location"
  type        = string
  default     = "nbg1"
}

variable "server_type" {
  description = "Hetzner Cloud Server Type"
  type        = string
  default     = "cx22"
}

variable "master_count" {
  description = "Number of Kubernetes master nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 1
}

variable "image" {
  description = "Node image"
  type        = string
  default     = "ubuntu-22.04"
}

variable "base_name" {
  description = "Base name for nodes"
  type        = string
  default     = "k3s"
}

variable "network_zone" {
  description = "Network zone for the private network"
  type        = string
  default     = "eu-central"
}