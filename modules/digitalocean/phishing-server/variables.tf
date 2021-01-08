variable "count" {
  default = 1
}

variable "ansible_playbook" {
  default = "../data/playbooks/install_gophish.yml"
  description = "Ansible Playbook to run"
}

variable "ansible_arguments" {
  default = []
  type    = "list"
  description = "Additional Ansible Arguments"
}

variable "ansible_vars" {
  default = []
  type    = "list"
  description = "Environment variables"
}

variable "size" {
  default = "s-1vcpu-1gb"
}

variable "regions" {
  type = "list"
  default = ["AMS3"]
}

variable "available_regions" {
  type = "map"
  default = {
    "NYC1" = "nyc1"
    "NYC2" = "nyc2"
    "NYC3" = "nyc3"
    "SFO1" = "sfo1"
    "SFO2" = "sfo2"
    "AMS2" = "ams2"
    "AMS3" = "ams3"
    "SGP1" = "sgp1"
    "LON1" = "lon1"
    "FRA1" = "fra1"
    "TOR1" = "tor1"
    "BLR1" = "blr1"
  }
}

variable "hostname-gophish" {
  type = "string"
}

variable "domain-gophish" {
  type = "string"
}

variable "slack" {
  type = "string"
}
