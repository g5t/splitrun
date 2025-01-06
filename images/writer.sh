#!/usr/bin/env bash

# Build a minimal Docker/Podman image containing the kafka-to-nexus binary
# using a pre-built image with CMake, Make, gcc, g++, Conan<2, and conan-dependencies
#
# Since files are copied between images by mounting their filesystems, we _must_
# use the `buildah unshare` command to run this executable script:
#
#   buildah unshare ./writer.sh [-w /path/to/kafka-to-nexus.git]

set -o errexit -o pipefail -o noclobber -o nounset

# Default value(s)
writer_dir=./writer-repo

### All of this to have a single optional flagged input:
! getopt --test >> /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
  # shellcheck disable=SC2016
  echo '`getopt --test` failed in this environment. Install "enhanced getopt" on your system.'
  exit 1
fi
LONG_OPTIONS=writer:
OPTIONS=w:
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONG_OPTIONS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  # getopt complained about wrong arguments to stdout
  exit 2
fi
eval set -- "$PARSED"
while true; do
  case "$1" in
    -w|--writer) writer_dir="$2"; shift 2 ;;
    --) shift; break; ;;
    *) echo "Programming error"; exit 3; ;;
  esac
done
###

# Make sure we have a copy of the repository
if [ ! -d "$writer_dir" ]; then
  echo "The provided ${writer_dir} is not a directory!"
  git clone https://gitlab.esss.lu.se/ecdc/ess-dmsc/kafka-to-nexus.git "$writer_dir"
fi

# Create the build container, which has CMake etc, and Conan already configured
builder=$(buildah from splitrun/base:v1)
buildat=$(buildah mount $builder)
# 

rwd=$(realpath $writer_dir)
rpd=$(dirname $rwd)

mkdir -p $buildat/opt/repo
rsync -a $rwd/ $buildat/opt/repo/.

buildah run $builder cmake -S /opt/repo -B /opt/repo/build -DCMAKE_BUILD_TYPE=Release
buildah run $builder cmake --build /opt/repo/build -j --target kafka-to-nexus

rsync -a $buildat/opt/repo/ $rpd/.

# A more-complete runtime is needed since we need access to Python :(
# # Create the runtime container
# runner=$(buildah from busybox:glibc)
# runat=$(buildah mount $runner)

# # Copy over the binary and libraries
# cp $buildat/opt/build/bin/* $runat/usr/bin/
# cp $buildat/opt/build/lib/*.so* $runat/lib64/
# # Copy over system libraries, identified with
# # LD_TRACE_LOADED_OBJECTS=1 bifrost
# for lib in crypt gcc_s stdc++; do
#   cp $buildat/lib64/lib$lib.so* $runat/lib64
# done

runner=$(buildah from almalinux:9)
runat=$(buildah mount $runner)
# Copy over the binary and libraries
cp $buildat/opt/repo/build/bin/* $runat/usr/bin/
cp $buildat/opt/repo/build/lib/*.so* $runat/lib64/
cp $buildat/opt/repo/src/Version.h $runat/.

# Install Python and the plumber utilities
buildah run $runner dnf -y install python3-pip git 
buildah run $runner dnf clean all 
buildah run $runner rm -rf /var/cache/yum
buildah run $runner python3 -m pip install git+https://github.com/g5t/mccode-plumber.git@v0.3.7

# Copy-over the entrypoint script
buildah copy $runner entrypoints/entrypoint-writer.sh entrypoint.sh
buildah run "$runner" chmod +x entrypoint.sh
# Make it the default entrypoint
buildah config --entrypoint /entrypoint.sh "${runner}"

# Now we're done with the build image
buildah unmount $builder

# Give the runtime image its name, and save it
image=splitrun/writer:v1
buildah config --label name=$image $runner
buildah unmount $runner
buildah commit $runner $image
