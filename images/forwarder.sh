#!/usr/bin/env bash

# Build a minimal Docker/Podman image to run the EPICS to Kafka forwarder.
#
# Since no files are copied between images by mounting their filesystems, 
# we don't need to use the `buildah unshare` command to run this executable script:
#
#   ./forwarder.sh

set -o errexit -o pipefail -o noclobber -o nounset

# Create a container
# We need python<3.12 for p4p and non-muslc for epicscorelibs :(
# So alpine is not a viable base image
container=$(buildah from almalinux:9)
buildah run $container dnf -y install python3 python3-pip git
buildah run $container dnf clean all && rm -rf /var/cache/yum

declare -a packages=(
  "git+https://github.com/g5t/ess-forwarder.git@explicit-submodules"
  "git+https://github.com/g5t/mccode-plumber.git@v0.3.7"
)
for package in "${packages[@]}"; do
  buildah run $container python3 -m pip install $package
done

buildah copy $container entrypoints/entrypoint-forwarder.sh entrypoint.sh
buildah run "$container" chmod +x entrypoint.sh
# Make that the default entrypoint
buildah config --entrypoint /entrypoint.sh "${container}"

# Make a Docker format image
image=splitrun/forwarder:v1
buildah config --label name=$image "$container"
buildah unmount "$container"
buildah commit "$container" $image
