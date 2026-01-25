# Silver
**_Modern Collaborative Email Platform_**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
![CI](https://img.shields.io/github/actions/workflow/status/LSFLK/silver/build-and-push-images.yml)
![Security Scan](https://img.shields.io/github/actions/workflow/status/LSFLK/silver/trivy-fs.yml?label=security)
![Last Commit](https://img.shields.io/github/last-commit/LSFLK/silver)

**Silver** aims to build a new kind of email and communication system that can work at a government scale. The goal is to make email faster, smarter, and easier to manage while keeping it secure and reliable. The platform will evolve in two stages: Version 1.0 delivers reliable, standards-compliant email, while Version 2.0 reimagines communication with modern collaboration at its core.

<p align="center">
  •   <a href="#why-silver">Why Silver?</a> •
  <a href="#key-features">Key Features</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#open-source-components">Open Source Components</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a> •
</p>

## Why Silver?
Silver is designed to be secure, reliable, and easy to manage. It runs entirely on your own hardware, giving you full control over your data and ensuring privacy. The system is lightweight and efficient, performing well even on minimal hardware, which makes it easy to deploy in a variety of environments. Each user has a single, unified identity, so an email address and user identity are seamlessly connected. You can bring your own identity provider or use Thunder to organize your users and map your organization hierarchically.

External firewalls are not required to filter emails, and attachments are stored separately in blob storage to save space and improve overall system performance. Silver also includes built-in observability, allowing administrators to monitor activity, detect issues early, and maintain smooth operation.

## Key Features

Silver offers powerful capabilities that set it apart from traditional email solutions:

| Feature | Status |
|---------|--------|
| **Unmatched Cost Efficiency** – Reduce enterprise email costs to near-zero infrastructure expense. | Completed |
| **Lightweight Infrastructure** – Run on minimal hardware without compromising performance | Completed |
| **Complete Data Ownership** – Full control over storage, access, and security | Completed |
| **Built-In Security Protection** – Enterprise-grade spam filtering and malware scanning | Completed |
| **Smart Attachment Storage** – Separate object storage for improved performance | Completed |
| **Professional Role-Based Identity** – Authoritative organizational email addresses | In Progress |
| **Identity Provider Integration** – Seamless integration with existing IdP systems | Planned |
| **Disaster-Proof Backups** – Configurable backup strategies for data protection | Planned |
| **Effortless Group Emailing** – Organize users into groups for simplified communication | Planned |
| **Email Workflow Automation** – Route emails through predefined workflows with tracking | Planned |
| **High-Performance Email Client** – Native IMAP and JMAP support for faster sync | Planned |
| **Email Expiration Control** – Set expiration dates and retention policies | Planned |

**[View Complete Feature List →](docs/FEATURE_LIST.md)**

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

- Run `bash scripts/setup/setup.sh` to set up the configs.

- Run `bash scripts/service/start-silver.sh` to start the mail server.

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
bash scripts/user/add_user.sh
```
- Follow the prompts to add a new user.

### Testing your setup
- Now that you have a working email server, you can test your configuration using the following links/scripts.

  - [mxtoolbox](https://mxtoolbox.com/SuperTool.aspx)
    - MxToolbox is a powerful online service that provides a suite of free diagnostic and lookup tools for troubleshooting email delivery, DNS, and network issues.
  - [mail-tester](https://www.mail-tester.com/)
    - Mail-Tester is a free online tool that analyzes the "spamminess" of your email and server configuration, providing a score out of 10 to help improve your email deliverability.
  

- You can also set up a Mail User Agent (MUA) like Thunderbird to send and receive emails. Follow the instructions in [Mail User Agent Setup](docs/Mail-User-Agent-Setup.md).

## Open Source Components

### Email Flow in Silver

<table>
<tr>
<td width="50%">

**Figure 1: Outbound Email Flow**

<img src="https://github.com/user-attachments/assets/17938298-8f0c-4558-9331-6e96272cb0ba" alt="Inbound Email Flow" width="100%" />

</td>
<td width="50%">

**Figure 2: Inbound Email Flow**

<img src="https://github.com/user-attachments/assets/de7e032b-7dfe-42b6-950b-9b59028ef06b" alt="Outbound Email Flow" width="100%" />

</td>
</tr>
</table>

Silver is built using open-source software.

- [Postfix](https://www.postfix.org/) - handles sending and receiving email.
- [Raven](https://github.com/lsflk/raven) - handles SASL authentication, LMTP, and IMAP server for email retrieval.
- [Thunder](https://github.com/asgardeo/thunder) - Identity provider and user manager
- [Rspamd](https://rspamd.com/) - spam filtering system.
- [ClamAV](https://docs.clamav.net/Introduction.html) -  virus scanning system.
- [Certbot](https://certbot.eff.org/) - Client software that talks to Let’s Encrypt to generate certificates.

## Contributing

Thank you for wanting to contribute to our project. Please see [CONTRIBUTING.md](https://github.com/LSFLK/silver/blob/main/docs/CONTRIBUTING.md) for more details.

## License 

Distributed under the Apache 2.0 License. See [LICENSE](https://github.com/LSFLK/silver/blob/main/LICENSE) for more information.
