# Services 
This folder contains all the services required for running your own mail server. 

Each service is self-contained and meant to be stateless. This allows for nicer separation, better testing and allows for changing services if they don't fit your needs.

Each service follows the following file structure but please refer to each service's readme for any deviations.

## Service File Structure

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




