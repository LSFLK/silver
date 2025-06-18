#!/bin/bash

# Init file for our tests.

# Test email from local network
./scripts/buildnrun.sh
echo "---------------"
sleep 3 # warm up time for docker container to be usable.
./scripts/sendmail.sh