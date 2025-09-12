# SPAM filter server

This directory contains configuration files to set up and run a local spam filter server using Rspamd.

## Create worker-controller.inc file
- Create a `worker-controller.inc` file in the `conf` directory with the following content. Replace `${BIND_SOCKET}`, `${PASSWORD}`, and `${ENABLE_PASSWORD}` with your desired values.

```bash
bind_socket = "${BIND_SOCKET}";
password = "${PASSWORD}";
enable_password = "${ENABLE_PASSWORD}";
```

## Access the Rspamd web interface
- Once the Rspamd container is running, you can access the Rspamd web interface by navigating to `http://localhost:${BIND_SOCKET_PORT}` in your web browser. Use the credentials you specified in the `worker-controller.inc` file to log in.
- You can monitor the spam filtering process and configure various settings through the web interface.