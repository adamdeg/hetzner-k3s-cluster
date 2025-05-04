output "master_ips" {
  value = hcloud_server.master.*.ipv4_address
}

output "worker_ips" {
  value = hcloud_server.worker.*.ipv4_address
}

output "k3s_api" {
  value = "https://${hcloud_server.master[0].ipv4_address}:6443"
}

output "k3s_token_command" {
  value = "To get the K3s token, run: ssh root@${hcloud_server.master[0].ipv4_address} 'cat /var/lib/rancher/k3s/server/token'"
}