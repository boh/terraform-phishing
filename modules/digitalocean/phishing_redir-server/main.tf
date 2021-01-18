terraform {
  required_version = ">= 0.12.0"
}

resource "random_id" "server" {
  count       = var.vmcount
  byte_length = 4
}

resource "tls_private_key" "ssh" {
  count     = var.vmcount
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "digitalocean_tag" "gophish-rdr" {
  name = "gophish-rdr"
}

#resource "digitalocean_domain" "examplecom" {
#    name = "example.com"
#    ip_address = "${digitalocean_droplet.redir-server.*.ipv4_address[count.index]}"
#}

# mail relay A record for host
resource "digitalocean_record" "domain" {
  name   = var.hostname-rdir
  type   = "A"
  domain = var.domain-rdir
  value  = digitalocean_droplet.redir-server[0].ipv4_address
}

# mail relay A record for domain
resource "digitalocean_record" "rdns" {
  name   = "@"
  type   = "A"
  domain = var.domain-rdir
  value  = digitalocean_droplet.redir-server[0].ipv4_address
}

# mail relay MX 
resource "digitalocean_record" "mx" {
  name     = "@"
  type     = "MX"
  priority = 10
  ttl      = 60

  domain = var.domain-rdir
  value  = "${var.hostname-rdir}.${var.domain-rdir}."
}

# mail relay TXT SPF
resource "digitalocean_record" "redir-server-mail-spf" {
  domain = var.domain-rdir
  name   = "@"
  value = "v=spf1 ip4:${digitalocean_droplet.redir-server[0].ipv4_address} ~all"
  type  = "TXT"
  ttl   = 60
}

# mail relay TXT DKIM placeholder
resource "digitalocean_record" "phishing-rdr-mail-dkim" {
  domain = var.domain-rdir
  name   = "mail._domainkey"
  #value  = "Change me please"
  value  = data.template_file.dkim[0].rendered
  type   = "TXT"
  ttl    = 60
}

# mail relay TXT DMARC
resource "digitalocean_record" "redir-server-email-dmarc" {
  domain = var.domain-rdir
  name   = "_dmarc"
  value  = "v=DMARC1; p=reject"
  type   = "TXT"
  ttl    = 60
}

resource "digitalocean_ssh_key" "ssh_key" {
  count      = var.vmcount
  name       = "redir-server-key-${random_id.server[count.index].hex}"
  public_key = tls_private_key.ssh[count.index].public_key_openssh
}

resource "digitalocean_droplet" "redir-server" {
  count = var.vmcount
  image = "ubuntu-18-04-x64"
  #name = "redir-server-${random_id.server.*.hex[count.index]}"
  name     = var.domain-rdir
  region   = var.available_regions[element(var.regions, count.index)]
  ssh_keys = [digitalocean_ssh_key.ssh_key[count.index].id]
  size     = var.size
  tags     = [digitalocean_tag.gophish-rdr.name]

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "export DEBIAN_FRONTEND=noninteractive; apt update && apt-get -y -qq install socat postfix postgrey opendmarc opendkim opendkim-tools postfix-policyd-spf-python mailutils",
      "echo ${var.domain-rdir} > /etc/mailname",
      "echo ${digitalocean_droplet.redir-server[0].ipv4_address} ${var.hostname-rdir}.${var.domain-rdir} ${var.hostname-rdir} >> /etc/hosts",
      "echo 127.0.1.1 ${var.hostname-rdir}.${var.domain-rdir} ${var.hostname-rdir} >> /etc/hosts",
      "echo ${var.hostname-rdir} > /etc/hostname",
      "apt-get install -y tmux python-pip",
    ]

    connection {
      host        = self.ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = tls_private_key.ssh[count.index].private_key_pem
    }
  }

  provisioner "file" {
    source      = "../data/postfix/header_checks"
    destination = "/etc/postfix/header_checks"
  }

  connection {
    host        = self.ipv4_address
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.ssh[count.index].private_key_pem
  }

  provisioner "local-exec" {
    command = "cp ../data/templates/install_postfix.tpl ../data/scripts/install_postfix.sh"
  }

  provisioner "local-exec" {
    command = "sed -i s/'@@full_primary_domain@@'/${var.hostname-rdir}.${var.domain-rdir}/g ../data/scripts/install_postfix.sh"
  }

  provisioner "local-exec" {
    command = "sed -i s/'@@primary_domain@@'/${var.domain-rdir}/g ../data/scripts/install_postfix.sh"
  }

  provisioner "local-exec" {
    command = "cp ../data/templates/run_certbot.tpl ../data/playbooks/run_certbot.yml"
  }

  provisioner "local-exec" {
    command = "sed -i s/'@@full_primary_domain@@'/${var.hostname-rdir}.${var.domain-rdir}/g ../data/playbooks/run_certbot.yml"
  }

  provisioner "local-exec" {
    command = "sed -i s/'@@relay_ip@@'/${element(var.relay_from, count.index)}/g ../data/scripts/install_postfix.sh"
  }

  provisioner "file" {
    source      = "../data/scripts/install_postfix.sh"
    destination = "/tmp/install_postfix.sh"
  }

  provisioner "file" {
    source      = "../data/scripts/run_certbot.sh"
    destination = "/tmp/run_certbot.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_postfix.sh",
      "cd /tmp",
      "chmod +x /tmp/run_certbot.sh",
      "./install_postfix.sh ${var.hostname-rdir}.${var.domain-rdir} | tee /tmp/install_postfix.log",
      "postmap /etc/postfix/header_checks",
      "postfix reload",
      "cut -d '\"' -f 2 \"/etc/opendkim/keys/${var.domain-rdir}/mail.txt\" | tr -d \"[:space:]\"",
    ]

    connection {
      host        = self.ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = tls_private_key.ssh[count.index].private_key_pem
    }
  }

  provisioner "local-exec" {
    command = "echo \"${tls_private_key.ssh[count.index].private_key_pem}\" > ../data/ssh_keys/${self.ipv4_address} && echo \"${tls_private_key.ssh[count.index].public_key_openssh}\" > ../data/ssh_keys/${self.ipv4_address}.pub && chmod 600 ../data/ssh_keys/*"
  }

  provisioner "local-exec" {
    command = "curl -X POST -H 'Content-type: application/json' --data '{\"text\":\"Droplet ${digitalocean_droplet.redir-server[0].name} created!\"}' ${var.slack}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "curl -X POST -H 'Content-type: application/json' --data '{\"text\":\"Droplet ${digitalocean_droplet.redir-server[0].name} destroyed!\"}' ${var.slack}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm  -f ../data/ssh_keys/${self.ipv4_address}*"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "cat /dev/null > /tmp/dkim.txt"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ../data/scripts/install_postfix.sh"
  }

  provisioner "local-exec" {
  command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ../data/ssh_keys/${digitalocean_droplet.redir-server[count.index].ipv4_address} root@${digitalocean_droplet.redir-server[count.index].ipv4_address}:/tmp/dkim.txt /tmp/dkim.txt"
}

  provisioner "local-exec" {
    command = "echo IP Address >> ../data/ips/${var.hostname-rdir}_${self.ipv4_address} && echo ========== >> ../data/ips/${var.hostname-rdir}_${self.ipv4_address} && echo ${self.ipv4_address} ${self.name} >> ../data/ips/${var.hostname-rdir}_${self.ipv4_address} && echo ========== >> ../data/ips/${var.hostname-rdir}_${self.ipv4_address} && echo Terraform state directory >> ../data/ips/${var.hostname-rdir}_${self.ipv4_address} && echo ========================= >> ../data/ips/${var.hostname-rdir}_${self.ipv4_address} && echo `pwd` >> ../data/ips/${var.hostname-rdir}_${self.ipv4_address}"
    }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ../data/ips/${var.hostname-rdir}_${self.ipv4_address}"
  }

}

resource "null_resource" "ansible_provisioner" {
  count = signum(length(var.ansible_playbook)) == 1 ? var.vmcount : 0

  #  depends_on = ["digitalocean_droplet.redir-server"]
  depends_on = [digitalocean_record.domain]

  triggers = {
    droplet_creation = join(",", digitalocean_droplet.redir-server.*.id)
    policy_sha1      = filesha1(var.ansible_playbook)
  }

  provisioner "local-exec" {
    command = "/usr/bin/ansible-playbook ${join(" ", compact(var.ansible_arguments))} --user=root --private-key=../data/ssh_keys/${digitalocean_droplet.redir-server[count.index].ipv4_address} -e host=${digitalocean_droplet.redir-server[count.index].ipv4_address} ${var.ansible_playbook}"
    #    environment {
    #      ANSIBLE_HOST_KEY_CHECKING = "False"
    #    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "template_file" "ssh_config" {
  count = var.vmcount

  template = file("../data/templates/ssh_config.tpl")

  depends_on = [digitalocean_droplet.redir-server]

  vars = {
    name     = "${var.hostname-rdir}_${digitalocean_droplet.redir-server[count.index].ipv4_address}"
    hostname = digitalocean_droplet.redir-server[count.index].ipv4_address
    user     = "root"
    #identityfile = "${path.root}/data/ssh_keys/${digitalocean_droplet.redir-server.*.ipv4_address[count.index]}"
    identityfile = "../data/ssh_keys/${digitalocean_droplet.redir-server[count.index].ipv4_address}"
  }
}

data "template_file" "run_certbot" {
  count = var.vmcount

  template = file("../data/templates/run_certbot.tpl")

  depends_on = [digitalocean_droplet.redir-server]

  vars = {
    full_primary_domain = "${var.hostname-rdir}.${var.domain-rdir}"
  }
}


data "template_file" "dkim" {
  count = var.vmcount

  template = file("/tmp/dkim.txt")

  depends_on = [digitalocean_droplet.redir-server]
}

resource "null_resource" "gen_ssh_config" {
  count = var.vmcount

  triggers = {
    template_rendered = data.template_file.ssh_config[count.index].rendered
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.ssh_config[count.index].rendered}' > ../data/ssh_configs/config_${random_id.server[count.index].hex}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ../data/ssh_configs/config_${random_id.server[count.index].hex}"
  }
}

resource "null_resource" "gen_run_certbot_sh" {
  count = var.vmcount

  triggers = {
    template_rendered = data.template_file.run_certbot[count.index].rendered
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.run_certbot[count.index].rendered}' > ../data/playbooks/run_certbot.yml"
  }
}

