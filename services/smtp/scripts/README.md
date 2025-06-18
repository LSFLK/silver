# Test Scripts

This directory contains a set of scripts designed to build, run, and test our local email functionality in a containerized environment using Docker.


## Dependencies
- Running these tests require [Docker](https://www.docker.com/products/docker-desktop/) installed and running. 
- The sendmail test also requires [swaks](https://jetmore.org/john/code/swaks/installation.html) installed.

## Quick Start

To run the complete test sequence, ensure the scripts are executable and run them from the smtp directory:

```bash
cd services/smtp
chmod +x ./scripts/*.sh
./scripts/init.sh
```

