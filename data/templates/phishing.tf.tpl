terraform {
  required_version = ">= 0.12.0"
}

module "phishing_server" {
  source           = "../modules/digitalocean/phishing-server"
  hostname-gophish = "@@CHANGE-ME-PHISHING-HOSTNAME@@"
  domain-gophish   = "@@CHANGE-ME-PHISHING-DOMAIN@@"
  slack            = "@@CHANGE-ME-SLACK-WEBHOOK@@"
}

module "phishing_redir_server" {
  source        = "../modules/digitalocean/phishing_redir-server"
  relay_from    = module.phishing_server.ips[0]
  hostname-rdir = "@@CHANGE-ME-REDIRECTION-HOSTNAME@@"
  domain-rdir   = "@@CHANGE-ME-REDIRECTION-DOMAIN@@"
  slack         = "@@CHANGE-ME-SLACK-WEBHOOK@@"
}
