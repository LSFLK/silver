#!/bin/bash

CONTAINER_NAME="smtp-test"

echo "--- Stopping and removing old container... ---"
docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true

echo "--- Building new Docker image... ---"
docker build -t smtp-server .

echo "--- Running new container... ---"
docker run \
    --env-file conf/config.env \
    -d \
    --rm \
    --name $CONTAINER_NAME \
    -p 127.0.0.1:2525:25 \
    smtp-server:latest

echo "--- Done. Container '$CONTAINER_NAME' is running. ---"