#!/bin/bash

#Arguements name of workflow to be run

sudo docker build --platform linux/amd64 -t netgent .
sudo docker run --rm \
--cap-add=NET_RAW \
--entrypoint /usr/local/bin/start-netgent-capture \
--env SSLKEYLOGFILE=/capture/test.log \
-p 8080:8080 \
-v "$PWD/capture_output:/capture" \
-v "$PWD/prudentiaPrompts/$1:/home/agent/app/executable.json:ro" \
netgent \
-e /home/agent/app/$1 \
-s
