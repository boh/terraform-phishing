terraform {
  required_version = ">= 0.11.0"
}

resource "random_id" "server" {
  count = "${var.count}"
  byte_length = 4
}

resource "tls_private_key" "ssh" {
  count = "${var.count}"
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "digitalocean_tag" "gophish-rdr" {
    name = "gophish-rdr"
}

#resource "digitalocean_domain" "examplecom" {
#    name = "example.com"
#    ip_address = "${digitalocean_droplet.redir-server.*.ipv4_address[count.index]}"
#}

# mail relay A record
resource "digitalocean_record" "domain" {
    name = "${var.hostname-rdir}"
    type = "A"
    domain = "${var.domain-rdir}"
    value = "${digitalocean_droplet.redir-server.*.ipv4_address[count.index]}"
}

# mail relay A record for domain
resource "digitalocean_record" "rdns" {
    name = "@"
    type = "A"
    domain = "${var.domain-rdir}"
    value = "${digitalocean_droplet.redir-server.*.ipv4_address[count.index]}"
}

# mail relay MX 
resource "digitalocean_record" "mx" {
    name = "@"
    type = "MX"
    priority = 10
    ttl = 60
    #domain = "${digitalocean_domain.domain.name}"
    domain = "${var.domain-rdir}"
    value = "${var.hostname-rdir}.${var.domain-rdir}."
}

# mail relay TXT SPF
resource "digitalocean_record" "redir-server-mail-spf" {
    domain = "${var.domain-rdir}"
    name   = "@"
    #value  = "v=spf1 ip4:${digitalocean_droplet.phishing-rdr.ipv4_address} include:_spf.google.com ~all"
    value  = "v=spf1 ip4:${digitalocean_droplet.redir-server.ipv4_address} ~all"
    type   = "TXT"
    ttl    = 60
}
# mail relay TXT DKIM placeholder
resource "digitalocean_record" "phishing-rdr-mail-dkim" {
    domain = "${var.domain-rdir}"
    name   = "mail._domainkey"
    value  = "Change me please"
    type   = "TXT"
    ttl    = 60
}
# mail relay TXT DMARC
resource "digitalocean_record" "redir-server-email-dmarc" {
    domain = "${var.domain-rdir}"
    name   = "_dmarc"
    value  = "v=DMARC1; p=reject"
    type   = "TXT"
    ttl    = 60
}

resource "digitalocean_ssh_key" "ssh_key" {
  count = "${var.count}"
  name  = "redir-server-key-${random_id.server.*.hex[count.index]}"
  public_key = "${tls_private_key.ssh.*.public_key_openssh[count.index]}"
}

resource "digitalocean_droplet" "redir-server" {
  count = "${var.count}"
  image = "ubuntu-18-04-x64"
  #name = "redir-server-${random_id.server.*.hex[count.index]}"
  name = "${var.domain-rdir}"
  region = "${var.available_regions[element(var.regions, count.index)]}"
  ssh_keys = ["${digitalocean_ssh_key.ssh_key.*.id[count.index]}"]
  size = "${var.size}"
  tags = ["${digitalocean_tag.gophish-rdr.name}"]

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
       "export DEBIAN_FRONTEND=noninteractive; apt update && apt-get -y -qq install socat postfix postgrey opendmarc opendkim opendkim-tools postfix-policyd-spf-python mailutils",
      "echo ${var.domain-rdir} > /etc/mailname",
      "echo ${digitalocean_droplet.redir-server.ipv4_address} ${var.hostname-rdir}.${var.domain-rdir} ${var.hostname-rdir} >> /etc/hosts",
      "echo 127.0.1.1 ${var.hostname-rdir}.${var.domain-rdir} ${var.hostname-rdir} >> /etc/hosts",
      "echo ${var.hostname-rdir} > /etc/hostname",
      "apt-get install -y tmux python-pip"
    ]

    connection {
        type = "ssh"
        user = "root"
        private_key = "${tls_private_key.ssh.*.private_key_pem[count.index]}"
    }
  }

  provisioner "file" {
    source = "../data/postfix/header_checks"
    destination = "/etc/postfix/header_checks"
  }

    connection {
        type = "ssh"
        user = "root"
        private_key = "${tls_private_key.ssh.*.private_key_pem[count.index]}"
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
    source = "../data/scripts/install_postfix.sh"
    destination = "/tmp/install_postfix.sh"
  }

    connection {
        type = "ssh"
        user = "root"
        private_key = "${tls_private_key.ssh.*.private_key_pem[count.index]}"
    }

  provisioner "file" {
    source = "../data/scripts/run_certbot.sh"
    destination = "/tmp/run_certbot.sh"
  }

    connection {
        type = "ssh"
        user = "root"
        private_key = "${tls_private_key.ssh.*.private_key_pem[count.index]}"
    }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_postfix.sh",
      "cd /tmp",
#      "postconf -e smtpd_tls_cert_file=/etc/letsencrypt/live/${var.hostname-rdir}.${var.domain-rdir}/fullchain.pem",
#      "postconf -e smtpd_tls_key_file=/etc/letsencrypt/live/${var.hostname-rdir}.${var.domain-rdir}/privkey.pem",
#      "postconf -e myhostname=${var.domain-rdir}",
#      "postconf -e mydestination=\"${var.domain-rdir}, $myhostname, localhost.localdomain, localhost\"",
#      "postconf -e mynetworks=\"127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 ${element(var.relay_from, count.index)}\"",
#      "mkdir -p \"/etc/opendkim/keys/${var.domain-rdir}\""
#      "cp /etc/opendkim.conf /etc/opendkim.conf.orig"
      "chmod +x /tmp/install_postfix.sh",
      "chmod +x /tmp/run_certbot.sh",
      "./install_postfix.sh ${var.hostname-rdir}.${var.domain-rdir} | tee /tmp/install_postfix.log",
      "postmap /etc/postfix/header_checks",
      "postfix reload",
      "cut -d '\"' -f 2 \"/etc/opendkim/keys/example.com/mail.txt\" | tr -d \"[:space:]\""
    ]

    connection {
        type = "ssh"
        user = "root"
        private_key = "${tls_private_key.ssh.*.private_key_pem[count.index]}"
    }
  }

  provisioner "local-exec" {
    command = "echo \"${tls_private_key.ssh.*.private_key_pem[count.index]}\" > ../data/ssh_keys/${self.ipv4_address} && echo \"${tls_private_key.ssh.*.public_key_openssh[count.index]}\" > ../data/ssh_keys/${self.ipv4_address}.pub && chmod 600 ../data/ssh_keys/*" 
  }

  provisioner "local-exec" {
    command = "curl -X POST -H 'Content-type: application/json' --data '{\"text\":\"Droplet ${digitalocean_droplet.redir-server.name} created!\"}' ${var.slack}"
  }

  provisioner "local-exec" {
    when = "destroy"
    command = "curl -X POST -H 'Content-type: application/json' --data '{\"text\":\"Droplet ${digitalocean_droplet.redir-server.name} destroyed!\"}' ${var.slack}"
  }

  provisioner "local-exec" {
    when = "destroy"
    command = "rm  -f ../data/ssh_keys/${self.ipv4_address}*"
  }

  provisioner "local-exec" {
    when = "destroy"
    command = "rm -f ../data/scripts/install_postfix.sh"
  }

}

resource "null_resource" "ansible_provisioner" {
  count = "${signum(length(var.ansible_playbook)) == 1 ? var.count : 0}"

#  depends_on = ["digitalocean_droplet.redir-server"]
  depends_on = ["digitalocean_record.domain"]

  triggers {
    droplet_creation = "${join("," , digitalocean_droplet.redir-server.*.id)}"
    policy_sha1 = "${sha1(file(var.ansible_playbook))}"
  }

  provisioner "local-exec" {
    command = "/usr/bin/ansible-playbook ${join(" ", compact(var.ansible_arguments))} --user=root --private-key=../data/ssh_keys/${digitalocean_droplet.redir-server.*.ipv4_address[count.index]} -e host=${digitalocean_droplet.redir-server.*.ipv4_address[count.index]} ${var.ansible_playbook}"

#    environment {
#      ANSIBLE_HOST_KEY_CHECKING = "False"
#    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "template_file" "ssh_config" {

  count    = "${var.count}"

  template = "${file("../data/templates/ssh_config.tpl")}"

  depends_on = ["digitalocean_droplet.redir-server"]

  vars {
    name = "redir_server_${digitalocean_droplet.redir-server.*.ipv4_address[count.index]}"
    hostname = "${digitalocean_droplet.redir-server.*.ipv4_address[count.index]}"
    user = "root"
    #identityfile = "${path.root}/data/ssh_keys/${digitalocean_droplet.redir-server.*.ipv4_address[count.index]}"
    identityfile = "../data/ssh_keys/${digitalocean_droplet.redir-server.*.ipv4_address[count.index]}"
  }

}

data "template_file" "run_certbot" {

  count    = "${var.count}"

  template = "${file("../data/templates/run_certbot.tpl")}"

  depends_on = ["digitalocean_droplet.redir-server"]

  vars {
    full_primary_domain = "${var.hostname-rdir}.${var.domain-rdir}"
  }

}

resource "null_resource" "gen_ssh_config" {

  count = "${var.count}"

  triggers {
    template_rendered = "${data.template_file.ssh_config.*.rendered[count.index]}"
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.ssh_config.*.rendered[count.index]}' > ../data/ssh_configs/config_${random_id.server.*.hex[count.index]}"
  }

  provisioner "local-exec" {
    when = "destroy"
    command = "rm -f ../data/ssh_configs/config_${random_id.server.*.hex[count.index]}"
  }

}

resource "null_resource" "gen_run_certbot_sh" {

  count = "${var.count}"

  triggers {
    template_rendered = "${data.template_file.run_certbot.*.rendered[count.index]}"
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.run_certbot.*.rendered[count.index]}' > ../data/playbooks/run_certbot.yml"
  }

}
