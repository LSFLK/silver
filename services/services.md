# Services 

This folder contains all the services required for running your own mail server. 

Each service is self-contained and are meant to be stateless. This allows for nicer seperation, better testing and allows for hotswapping services if they don't fit your needs.

Each service follows the following file structure but please refer to each service's readme for further clarification.

## File Structure

```
services
└───servicename1
│   │   DockerFile
│   │   README.Docker.md
│   │
│   └───conf
│       │   configfile1.cf
│       │   configfile2.cf
│       │   ...
│   ...
  compose.yaml
  services.md
```


## Software
- Postfix - MTA handling sending and receiving mail
- Dovecot - MDA handling the storing of mails
- rspamd - Spam filtering system 
- sqlite - database for handling users




