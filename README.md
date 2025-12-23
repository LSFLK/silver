# Silver
**_Modern Collaborative Email Platform_**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
![CI](https://img.shields.io/github/actions/workflow/status/LSFLK/silver/build-and-push-images.yml)
![Security Scan](https://img.shields.io/github/actions/workflow/status/LSFLK/silver/trivy-fs.yml?label=security)
![Last Commit](https://img.shields.io/github/last-commit/LSFLK/silver)

**Silver** aims to build a new kind of email and communication system that can work at a government scale. The goal is to make email faster, smarter, and easier to manage while keeping it secure and reliable. The platform will evolve in two stages: Version 1.0 delivers reliable, standards-compliant email, while Version 2.0 reimagines communication with modern collaboration at its core.

<p align="center">
  •   <a href="#why-silver">Why Silver?</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#contributing">Open Source Components</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a> •
</p>

## Why Silver?
Silver is designed to be secure, reliable, and easy to manage. It runs entirely on your own hardware, giving you full control over your data and ensuring privacy. The system is lightweight and efficient, performing well even on minimal hardware, which makes it easy to deploy in a variety of environments. Each user has a single, unified identity, so an email address and user identity are seamlessly connected. You can bring your own identity provider or use Thunder to organize your users and map your organization hierarchically.

External firewalls are not required to filter emails, and attachments are stored separately in blob storage to save space and improve overall system performance. Silver also includes built-in observability, allowing administrators to monitor activity, detect issues early, and maintain smooth operation.

## Getting Started
### Prerequisites
- A dedicated Linux server with a static public IP address. You also require root access and port access control.
- Domain with DNS control

### Minimum hardware requirements
- 4GB of memory

### Software 
- Ensure you have [Git](https://git-scm.com/downloads/linux) and [Docker Engine](https://docs.docker.com/engine/install/) installed
  
### DNS setup
You own <a>example.com</a> and want to send an email as person@example.com.

You will need to add a few records to your DNS control panel.

> [!Note]
> Replace example.com and 12.34.56.78 in the below example with your domain and ip address.

| DNS Record | Name        | Value                                                  |
| ---------- | ----------- | ------------------------------------------------------ |
| A          | mail        | 12.34.56.78                                            |
| A          | example.com | 12.34.56.78                                            |
| MX         | example.com | mail.example.com                                       |
| TXT        | example.com | "v=spf1 ip4:12.34.56.78 ~all"                          |
| TXT        | _dmarc      | "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com" |
| PTR        | 12.34.56.78 | mail.example.com                                       |

> [!Tip]
> PTR records are usually set through your hosting provider. 

### Server Setup
-  Use the below command to clone the Silver Repo and navigate to the silver folder.

```bash
git clone https://github.com/LSFLK/silver.git
cd silver
```

### Configuration
- Open [`silver.yaml`](https://github.com/LSFLK/silver/blob/main/conf/silver.yaml) with a text editor.

- Enter your domain name.

- Run `bash ../scripts/setup/setup.sh` to set up the configs.

- Run `bash ../scripts/service/start-silver.sh` to start the mail server.

- Replace the dkim record below with the output you get after running the `setup.sh` script

| DNS Record | Name            | Value                                                                                                                                                                                                                                                  |
| ---------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| TXT        | mail._domainkey | "v=DKIM1; h=sha256; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDYZd3CAas0+81zf13cvtO6o0+rlGx8ZobYQXRR9W8qcJOeO1SiQGx8F4/DjZE1ggujOaY1bkt8OnUg7vG7/bk5PNe05EHJrg344krodqCJrVI74ZzEB77Z1As395KX6/XqbQxBepQ8D5+RpGFOHitI443G/ZWgZ6BRyaaE6t3u0QIDAQAB" |

> [!Important] 
> Ensure that your dkim value is correctly formatted.

### Adding users

- To add more users to your email server, open up [`users.yaml`](https://github.com/LSFLK/silver/blob/main/conf/users.yaml), and add their usernames and run the following command.

```bash
# silver/services
bash ../scripts/user/add_user.sh
```
- Follow the prompts to add a new user.

### Testing your setup
- Now that you have a working email server, you can test your configuration using the following links/scripts.

  - [mxtoolbox](https://mxtoolbox.com/SuperTool.aspx)
    - MxToolbox is a powerful online service that provides a suite of free diagnostic and lookup tools for troubleshooting email delivery, DNS, and network issues.
  - [mail-tester](https://www.mail-tester.com/)
    - Mail-Tester is a free online tool that analyzes the "spamminess" of your email and server configuration, providing a score out of 10 to help improve your email deliverability.
  

- You can also set up a Mail User Agent (MUA) like Thunderbird to send and receive emails. Follow the instructions in [Mail User Agent Setup](docs/Mail-User-Agent-Setup.md).

## Open Source Software

Silver is built using opensource software.

- [Postfix](https://www.postfix.org/) - handles sending and receiving email.
- [Raven](https://github.com/lsflk/raven) - handles SASL authentication, LMTP, and IMAP server for email retrieval.
- [Thunder](https://github.com/asgardeo/thunder) - Identity provider and user manager
- [Rspamd](https://rspamd.com/) - spam filtering system.
- [ClamAV](https://docs.clamav.net/Introduction.html) -  virus scanning system.

## Contributing

Thank you for wanting to contribute to our project. Please see [CONTRIBUTING.md](https://github.com/LSFLK/silver/blob/main/docs/CONTRIBUTING.md) for more details.

## License 

Distributed under the Apache 2.0 License. See [LICENSE](https://github.com/LSFLK/silver/blob/main/LICENSE) for more information.

## Miscellaneous

- [Interesting Email Products to Emerge Recently](docs/New-Email-Products.md)
