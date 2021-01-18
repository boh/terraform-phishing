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

resource "digitalocean_tag" "gophish" {
  name = "gophish"
}

#resource "digitalocean_domain" "digitaloceandomain" {
#    name = "example.com"
#    #ip_address = "${digitalocean_droplet.nginx_server.ipv4_address}"
#    ip_address = "${digitalocean_droplet.phishing-server.*.ipv4_address[count.index]}"
#}

resource "digitalocean_record" "digitaloceanrecordA" {
  name = var.hostname-gophish
  type = "A"
  domain = var.domain-gophish
  value  = digitalocean_droplet.phishing-server[0].ipv4_address
}

resource "digitalocean_ssh_key" "ssh_key" {
  count      = var.vmcount
  name       = "phishing-server-key-${random_id.server[count.index].hex}"
  public_key = tls_private_key.ssh[count.index].public_key_openssh
}

resource "digitalocean_droplet" "phishing-server" {
  count = var.vmcount
  image = "ubuntu-18-04-x64"
  #name = "phishing-server-${random_id.server.*.hex[count.index]}"
  name     = "${var.hostname-gophish}.${var.domain-gophish}"
  region   = var.available_regions[element(var.regions, count.index)]
  ssh_keys = [digitalocean_ssh_key.ssh_key[count.index].id]
  size     = var.size
  tags     = [digitalocean_tag.gophish.name]

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y tmux python-pip",
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
    when    = destroy
    command = "rm  -f ../data/ssh_keys/${self.ipv4_address}*"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "cat /dev/null > /tmp/dkim.txt"
  }

  provisioner "local-exec" {
    command = "echo IP Address >> ../data/ips/${var.hostname-gophish}_${self.ipv4_address} && echo ========== >> ../data/ips/${var.hostname-gophish}_${self.ipv4_address} && echo ${self.ipv4_address} ${self.name} >> ../data/ips/${var.hostname-gophish}_${self.ipv4_address} && echo ========== >> ../data/ips/${var.hostname-gophish}_${self.ipv4_address} && echo Terraform state directory >> ../data/ips/${var.hostname-gophish}_${self.ipv4_address} && echo ========================= >> ../data/ips/${var.hostname-gophish}_${self.ipv4_address} && echo `pwd` >> ../data/ips/${var.hostname-gophish}_${self.ipv4_address}"
    }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ../data/ips/${var.hostname-gophish}_${self.ipv4_address}"
  }


  provisioner "local-exec" {
    command = "curl -X POST -H 'Content-type: application/json' --data '{\"text\":\"Droplet ${digitalocean_droplet.phishing-server[0].name} created!\"}' ${var.slack}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "curl -X POST -H 'Content-type: application/json' --data '{\"text\":\"Droplet ${digitalocean_droplet.phishing-server[0].name} destroyed!\"}' ${var.slack}"
  }
}

resource "null_resource" "ansible_provisioner" {
  count = signum(length(var.ansible_playbook)) == 1 ? var.vmcount : 0

  #  depends_on = ["digitalocean_droplet.phishing-server"]
  depends_on = [digitalocean_record.digitaloceanrecordA]

  triggers = {
    droplet_creation = join(",", digitalocean_droplet.phishing-server.*.id)
    policy_sha1      = filesha1(var.ansible_playbook)
  }

  provisioner "local-exec" {
    command = "/usr/bin/ansible-playbook ${join(" ", compact(var.ansible_arguments))} --user=root --private-key=../data/ssh_keys/${digitalocean_droplet.phishing-server[count.index].ipv4_address} -e host=${digitalocean_droplet.phishing-server[count.index].ipv4_address} ${var.ansible_playbook}"
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

  depends_on = [digitalocean_droplet.phishing-server]

  vars = {
    name     = "${var.hostname-gophish}_${digitalocean_droplet.phishing-server[count.index].ipv4_address}"
    hostname = digitalocean_droplet.phishing-server[count.index].ipv4_address
    user     = "root"
    identityfile = "../data/ssh_keys/${digitalocean_droplet.phishing-server[count.index].ipv4_address}"
  }
}

data "template_file" "install_gophish" {
  count = var.vmcount

  template = file("../data/templates/install_gophish.tpl")

  depends_on = [digitalocean_droplet.phishing-server]

  vars = {
    full_primary_domain = "${var.hostname-gophish}.${var.domain-gophish}"
  }
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

resource "null_resource" "gen_install_gophish" {
  count = var.vmcount

  triggers = {
    template_rendered = data.template_file.install_gophish[count.index].rendered
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.install_gophish[count.index].rendered}' > ../data/playbooks/install_gophish.yml"
  }
}

