#!/usr/bin/env bash

# Build a minimal Docker/Podman image to build kafka-to-nexus (the file writer)
# and Event Formation Unit binaries
# Result contains CMake, Make, gcc, g++, Conan<2, and conan-dependencies for both
#
# Since no files are copied between images by mounting their filesystems, 
# we don't need to use the `buildah unshare` command to run this executable script:
#
#   ./base.sh [-e /path/to/efu/conanfile.txt] [-w /path/to/writer/conanfile.txt]

set -o errexit -o pipefail -o noclobber -o nounset


# Default value(s)
efu_file=./efu-repo
writer_file=./writer-repo

### All of this to have a single optional flagged input:
! getopt --test >> /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
  # shellcheck disable=SC2016
  echo '`getopt --test` failed in this environment. Install "enhanced getopt" on your system.'
  exit 1
fi
LONG_OPTIONS=efu:,writer:
OPTIONS=e:,w:
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONG_OPTIONS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  # getopt complained about wrong arguments to stdout
  exit 2
fi
eval set -- "$PARSED"
while true; do
  case "$1" in
    -e|--efu) efu_file="$2"; shift 2; ;;
    -w|--writer) writer_file="$2"; shift 2 ;;
    --) shift; break; ;;
    *) echo "Programming error"; exit 3; ;;
  esac
done
###

# Allow for specifying directories instead of the actual conan files
if [ -d "$efu_file" ]; then
    efu_file="${efu_file}/conanfile.txt"
fi
if [ ! -f "$writer_file" ]; then
    writer_file="${writer_file}/conanfile.txt"
fi

# but the files must exist
if [ ! -f "$efu_file" ]; then
    echo "Provided Event Formation Unit conanfile.txt ${efu_file} does not exist"
    exit 1
fi
if [ ! -f "$writer_file" ]; then
    echo "Provided kafka-to-nexus conanfile.txt ${efu_file} does not exist"
    exit 1
fi


container=$(buildah from alpine:latest)

buildah run $container apk add cmake make py3-pip git gcc g++
buildah run $container python3 -m pip install --root-user-action=ignore --break-system-packages "conan<2"
buildah run $container conan profile new --detect default
buildah run $container conan config install https://github.com/ess-dmsc/conan-configuration.git
buildah run $container conan profile update settings.compiler.libcxx=libstdc++11 default
buildah run $container conan profile update settings.compiler.version=12 default

# Actually building the conan dependencies fails. This is a waste of time.
for file in $efu_file $writer_file; do
  buildah copy $container $file conanfile.txt
  buildah run $container conan install conanfile.txt -pr default -g=cmake --build=outdated --no-imports
  buildah run $container rm conanfile.txt
done

image=splitrun/base:v2
buildah config --label name=$image $container
buildah unmount $container
buildah commit $container $image
