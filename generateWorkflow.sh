#!/bin/bash

#Arguements name of workflow to be generated, name of log file
KEY=$(python3 -c "import json;print(json.load(open('api_keys.json'))['google_api_key'])")
sudo docker builder prune -a
sudo docker build --platform linux/amd64 -t netgent .


sudo docker run --rm -it \
  -p 8080:8080 \
  -e GOOGLE_API_KEY="$KEY" \
  -v "$PWD/prudentiaPrompts:$PWD/prudentiaPrompts" \
  --entrypoint bash \
  netgent \
  $PWD/prudentiaPrompts/run_py_in_container.sh \
  $PWD/prudentiaPrompts/$1 > $2
