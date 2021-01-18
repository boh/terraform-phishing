# terraform-phishing

- This set of scripts is heavily based on *Red Baron*, which is a set of [modules](https://www.terraform.io/docs/modules/index.html) and custom/third-party providers for [Terraform](https://www.terraform.io/) which tries to automate creating resilient, disposable, secure and agile infrastructure for Red Teams.

- The main goal of this project is to build a phishing server (Gophish) together with SMTP-redirector (Postfix) automatically in Digital Ocean.

- When you create a droplet(s), you're provided also with SSH keys to automatically SSH into it and if you configure SSH autocompletion you make your life even easier.
- Digital Ocean firewall rules are included to allow only intended inbound and outgoing traffic. 
- DNS records (A,MX, TXT SPF, TXT DMARC, TXT DKIM) are added as well.

- You get a notification when the droplet is created/destroyed on your Slack channel (if you setup one).

- This configuration resulted in **Default Email from Gophish: 10/10** rating on [mail-tester.com](https://www.mail-tester.com/).

- Installed gophish version is modified, you can track WORD documents, have default landing page (like 404) etc.

- After the terraform apply is over, you can connect to https://YOUR-PHISHING-SERVER:3333, where your Gophish lives. You can alter the Gophish configuration (for example listen on localhost:3333 only) under /opt/gophish/config.json.



# Setup

Let's assume there's a domain called **opsecfail.me** a I want to use it in this project. Going through the following list of steps should give you a clear overview how to setup this domain and automate the creation of Phishing infrastructure.

First we need the API key for your Digital Ocean account, when you have it ready, save it - it'll be used to authenticate the terraform API calls. I usually save it as a ENV variable via `#~ export DIGITALOCEAN_TOKEN="token"` under `~/.zshrc`.

Our phishig domain has to be managed via Digital Ocean, if you registered the domain on Godaddy, Namecheap or other registrar we need to **Add** it.

![DO_create_domain](../docs/DO_create_domain.png)

The newly added domain has only these DNS records set:

![DO_created_fresh_domain](../docs/DO_created_fresh_domain.png)

We should verify, if it's true:

```
> dig @8.8.8.8 +short NS opsecfail.me
ns1.digitalocean.com.
ns2.digitalocean.com.
ns3.digitalocean.com.
```

To provision the droplets, combination of Terraform and Ansible is used, let's install it.

Install **Ansible** to be able run ansible-playbook. 

```
> ls -l /usr/bin/ansible-playbook
lrwxrwxrwx 1 root root 7 Jul 11  2019 /usr/bin/ansible-playbook -> ansible
```

Edit ansible defaults `~/.ansible.cfg` and add:

```
[defaults]
host_key_checking = False
command_warnings=False
```

Install **Terraform** version 0.12 from https://releases.hashicorp.com/terraform/0.12.0/terraform_0.12.0_linux_amd64.zip 

If you haven't already clone this repository and go to `terraform-phishing/config-phish` directory.

Run the `./init.sh` script, it'll create a main terraform config file for you (in the config-phish directory) by asking you about:

- Your phishing server hostname (*mandatory*)
- Your phishing server domain (*mandatory*)
- Your redirection server hostname (*mandatory*)
- Your redirection server domain (*mandatory*)
- Your Slack Webhook URL (*optional*)

Example:

```
> ./init.sh
[+] Copying Terraform phishing template to current directory.
Enter your phishing server hostname [for example www]: www7
Enter your phishing server domain [for example example.com]: opsecfail.me
Enter your mail redirection server hostname [for example mail:] mail7
Enter your mail redirection server domain [for example example.com]: opsecfail.me
Enter your Slack Webhook URL: https://hooks.slack.com/services/[...SNIP...]/[...SNIP...]
Your phishing setup:
Phishing server: www7.opsecfail.me
Redirection server: mail7.opsecfail.me
Slack Webhook https://hooks.slack.com/services/[...SNIP...]/[...SNIP...]
[+] Terraform config setup done.
[+] Creating file for DKIM retrieval and setup at /tmp/dkim.txt
[+] Changes done. Check your phishing.tf
[+] If everything is OK, run the terraform (for this project I recommend version 0.12) in this current directory config-phish:
terraform init
terraform plan
terraform apply
```

Manually inspect the config file `phishing.tf` and proceed.

Still in the `config-phish` directory, you must run the `terraform init` do initialize all the providers, then `terraform plan` to create a state file and validate the config, it everything looks OK finally `terraform apply` to apply the changes and create two droplets.

Running the `terraform apply` will ask for a confirmation.

![DO_terraform_apply_first](../docs/DO_terraform_apply_first.png)

After the command finishes you should see similar output:

![DO_terraform_apply](../docs/DO_terraform_apply.png)

You should have now two droplets created and the DNS records for the domain set:

![DO_configured_domain](../docs/DO_configured_domain.png)

If you've setup also the Slack Webhook, new messages appeared:

![DO_slack_chan](../docs/DO_slack_chan.png)

After your campaign is over, delete the droplets, by issuing this command `terraform destroy`

![DO_terraform_destroyed](../docs/DO_terraform_destroyed.png)

DNS records will be removed as well.

![DO_dns-records-after-destroy](../docs/DO_dns-records-after-destroy.png)

## Tips

### List of Droplet's IP addresses

I recommend using the Zsh to make your life easier. 

Consider also adding the following alias to you `~/.zshrc`

```
alias ips="ls -l /CHANGE-TO-WHERE-YOUR-PROJECT-IS/terraform-phishing/data/ips | cut -d ' ' -f 9,10 | cut -d ' ' -f 2 | sed 's/_/  \:  /g'"
```

After you create a droplet this way, you can just use command `ips` to quickly see the IP address and hostname:

```
> ips

mail7  :  178.62.252.153
www7  :  188.166.75.45
```

### SSH Auto-completion

And If you configure SSH autocompletion, you can SSH into those droplets just by typing:

```
ssh mail7<TAB>
ssh mail7_188.166.110.247<ENTER>
```

### How ENABLE SSH autocompletion under Zsh with Oh-My-Zsh

This guide was stolen from the Red-Baron WIKI.

- Put the following at the **very top** of your `~/.ssh/config` file, **make sure to use the absolute path to the terraform-phishing folder**:

```
Include <Path to terraform-phishing folder>/data/ssh_configs/*
```

- Copy the custom ssh completion file (which was stolen from [here](https://github.com/zsh-users/zsh/commit/5ded0ad96740b62ea0214387ee260b515726a05e)) under [autocompletions/zsh](https://github.com/byt3bl33d3r/Red-Baron/blob/master/autocompletions/zsh) to your oh-my-zsh folder:

```
cp ~/terraform-phishing/Red-Baron/autocompletions/zsh/_ssh ~/.oh-my-zsh/completions
```

- Restart your terminal
- All created infrastructure will now show up when you tab complete the `ssh` command! e.g. `ssh http<TAB>`

Currently the ssh_keys path is defined as (**../data/ssh_keys/**), the SSH works (if ssh config was configured) from the config-phishing directory. If you'd like to set another fixed location, so in your env the SSH works generally, edit the `main.tf` module files and change the line `identityfile = "../data/ssh_keys/${digitalocean_droplet.phishing-server[count.index].ipv4_address}"`

# Known Bugs/Limitations

- You need to **install Ansible**. 
- Terraform **v0.12** was used. You can get this older version of terraform [here](https://releases.hashicorp.com/terraform/). Why? Because some neat features were sadly removed in newer versions of terraform..
- SSH keys are deleted only when you explicitly run ```terraform destroy``` (https://github.com/hashicorp/terraform/issues/13549)
- Currently this project is meant to create a phishing environment which is burnt after the campaign is over, the variable count was **never tested** with value > 1. 
- LetsEncrypt si installed via snapd. <u>Make sure your DNS works!</u> 
- To set a DKIM DNS record a file /tmp/dkim.txt is created, change the location if needed.

# Original Author and Acknowledgments

Original Author: Marcello Salvati ([@byt3bl33d3r](https://twitter.com/byt3bl33d3r))

# License

This fork of the original Red Baron /  repository is licensed under the GNU General Public License v3.0.
