#!/usr/bin/env bash

# Build a minimal Docker/Podman image containing all Event Formation Unit binaries
# using a pre-built image with CMake, Make, gcc, g++, Conan<2, and conan-dependencies
#
# Since files are copied between images by mounting their filesystems, we _must_
# use the `buildah unshare` command to run this executable script:
#
#   buildah unshare ./efu.sh [-e /path/to/event-formation-unit.git]

set -o errexit -o pipefail -o noclobber -o nounset

# Default value(s)
efu_dir=./efu-repo

### All of this to have a single optional flagged input:
! getopt --test >> /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
  # shellcheck disable=SC2016
  echo '`getopt --test` failed in this environment. Install "enhanced getopt" on your system.'
  exit 1
fi
LONG_OPTIONS=efu:
OPTIONS=e:
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONG_OPTIONS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  # getopt complained about wrong arguments to stdout
  exit 2
fi
eval set -- "$PARSED"
while true; do
  case "$1" in
    -e|--efu) efu_dir="$2"; shift 2; ;;
    --) shift; break; ;;
    *) echo "Programming error"; exit 3; ;;
  esac
done
###

# Make sure we have a copy of the repository
if [ ! -d "$efu_dir" ]; then
  git clone https://github.com/ess-dmsc/event-formation-unit.git "$efu_dir"
fi

# Create the build container, which has CMake etc, and Conan already configured
builder=$(buildah from splitrun/base:v1)
buildat=$(buildah mount $builder)
# 
mkdir -p $buildat/opt/repo
mkdir -p $buildat/opt/build
cp -r $(realpath $efu_dir)/* $buildat/opt/repo/.

buildah run $builder cmake -S /opt/repo -B /opt/build -DCMAKE_BUILD_TYPE=Release
buildah run $builder cmake --build /opt/build --target allefus copylibs -j

# Create the runtime container
runner=$(buildah from busybox:glibc)
runat=$(buildah mount $runner)

# Copy over the binary and libraries
cp $buildat/opt/build/bin/* $runat/usr/bin/
cp $buildat/opt/build/lib/*.so* $runat/lib64/
# Copy over system libraries, identified with
# LD_TRACE_LOADED_OBJECTS=1 bifrost
for lib in crypt gcc_s stdc++; do
  cp $buildat/lib64/lib$lib.so* $runat/lib64
done

# Now we're done with the build image
buildah unmount $builder

# Give the runtime image its name, and save it
image=splitrun/efu:v1
buildah config --label name=$image $runner
buildah unmount $runner
buildah commit $runner $image
