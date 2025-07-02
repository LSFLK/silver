# Services
This folder contains all the services required for running your own mail server. 

## Quick Start

- Ensure your DNS records (A, MX, SPF, DKIM, DMARC) are set and valid.

- Ensure [git](https://git-scm.com/downloads/linux) and the [Docker Engine](https://docs.docker.com/engine/install/) are installed.

### Setup
```
  git clone https://github.com/LSFLK/silver.git
  cd silver/services
```

- Add your domain and email into the .env file.

```
  docker compose up -d
```

- View logs for any errors using

```
  docker compose logs -f
```


## Service File Structure

Each service is self-contained and meant to be stateless. This allows for nicer separation, better testing and allows for changing services if they don't fit your needs.

Each service follows the following file structure but please refer to each service's readme for any deviations.

```

services
└───servicename
│   │   DockerFile
│   │   README.Docker.md
|   └───scripts/
│   └───conf/
│       │   config_file_1.cf
│       │   ...
│       │   ...
│   ...
  compose.yaml
  services.md

```


## Software
- Postfix - handles sending and receiving mail (MTA)
- Dovecot - handles the storing of mails (MDA)
- Rspamd -  spam filtering system 
- Sqlite -  database for handling users and system data.




