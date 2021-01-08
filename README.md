# terraform-phishing

- This set of scripts is heavily based on *Red Baron*, which is a set of [modules](https://www.terraform.io/docs/modules/index.html) and custom/third-party providers for [Terraform](https://www.terraform.io/) which tries to automate creating resilient, disposable, secure and agile infrastructure for Red Teams.

- The main goal of this project is to build a phishing server (Gophish) together with SMTP-redirector (Postfix) automatically in Digital Ocean.

- When you create a droplet(s), you're provided also with SSH keys to automatically SSH into it and if you configure SSH autocompletion you make your life even easier.
- DO firewall rules are included to allow only intened inbound and outgoing traffic. 
- DNS records (A,MX, TXT SPF, TXT DMARC, TXT DKIM) are added as well.

- You get a notification when the droplet is created/destroyed on your Slack channel.

- This configuration resulted in **Default Email from Gophish: 10/10** rating on [mail-tester.com](https://www.mail-tester.com/).


# Original Author and Acknowledgments

Original Author: Marcello Salvati ([@byt3bl33d3r](https://twitter.com/byt3bl33d3r))

# Setup

**Read and change config-phish/phishing.tf** 

```
# cd config-phish
# Change the hostname and domain for phishing-server and redir-server (DNS records).
# Change the Slack webhook URL.
# Change email@example.com in data/scripts/run_certbot.sh
# search for example.com and change if needed 

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

# Run:

#~ terraform init
#~ terraform plan
#~ terraform apply
```

# Known Bugs/Limitations

- You need to **install Ansible**. 
- **terraform-provider-digitalocean_v1.23.0** provider was used . Terraform init might provide you with version 2.xx which is not compatible with this project.
- SSH keys are deleted only when you explicitly run ```terraform destroy``` (https://github.com/hashicorp/terraform/issues/13549)
- Currently this project is meant to create a phishing environment which is burnt after the campaign is over, the variable count was **never tested** with value > 1. 
- LetsEncrypt si installed via snapd. <u>Make sure your DNS works!</u> 
- Make sure you change the value of TXT DKIM to a proper one. You can find it in the terraform output  on the line: module.phishing_redir_server.digitalocean_droplet.redir-server (remote-exec): **v=DKIM1;h=sha256;k=rsa;[...SNIP...]**

# License

This fork of the original Red Baron /  repository is licensed under the GNU General Public License v3.0.
