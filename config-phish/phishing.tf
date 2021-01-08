terraform {
  required_version = ">= 0.11.0"
}

module "phishing_server" {
  source = "../modules/digitalocean/phishing-server"
  hostname-gophish = "www"
  domain-gophish = "example.com"
  slack = "https://hooks.slack.com/.........."
}

module "phishing_redir_server" {
  source = "../modules/digitalocean/phishing_redir-server"
  relay_from = "${module.phishing_server.ips}"
  hostname-rdir = "mail"
  domain-rdir = "example.com"
  slack = "https://hooks.slack.com/.........."
}
