#!/usr/bin/env bash

# check if the expected containers are running:
declare -A containers
for i in $(podman ps --format '{{.Names}}'); do
  containers[$i]=1
done
for expected in broker forwarder writer efu; do
  if [ ! ${containers[$expected]} ]; then
    echo "Expected container '${expected}' to be running"
    exit 1
  fi
done

echo "All expected containers are running"