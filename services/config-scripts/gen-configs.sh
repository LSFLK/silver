#!/bin/bash

bash ./config-scripts/gen-certbot-certs.sh
bash ./config-scripts/gen-opendkim-conf.sh
bash ./config-scripts/gen-rspamd-conf.sh
bash ./config-scripts/gen-postfix-conf.sh
bash ./config-scripts/gen-thunder-certs.sh
