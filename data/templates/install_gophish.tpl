---
- hosts: localhost
  gather_facts: True
  check_mode: no
  tasks:
  - name: Add IP address to the in-memory inventory
    add_host:
      name: "{{ host }}"
      groups: all

- name: Playbook for Phishing server setup.
  hosts: all
  tasks:

   - name: Install and setup Gophish instance
     shell: wget -N https://raw.githubusercontent.com/boh/gophish/master/run.sh && chmod +x /root/run.sh && /bin/bash -c "source /root/run.sh ${full_primary_domain} 2>&1 >> /tmp/debug.log"
