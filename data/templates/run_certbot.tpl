---
- hosts: localhost
  gather_facts: True
  check_mode: no
  tasks:
  - name: Add IP address to the in-memory inventory
    add_host:
      name: "{{ host }}"
      groups: all

- name: Playbook for Letsencrypt installation and cert req.
  hosts: all
  tasks:

   - name: Install and setup Letsencrypt for the redir.
     shell: chmod +x /tmp/run_certbot.sh && /bin/bash -c "/tmp/run_certbot.sh ${full_primary_domain} 2>&1 >> /tmp/letsencrypt.log"
