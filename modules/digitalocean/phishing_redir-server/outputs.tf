output "ips" {
  value = ["${digitalocean_droplet.redir-server.*.ipv4_address}"]
}

output "ssh_user" {
  value = "root"
}
