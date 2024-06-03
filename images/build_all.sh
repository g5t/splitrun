#!/bin/bash
EFUREPO=$(realpath efu-repo)
WRITERREPO="$(realpath writer-repo)"

# ./base.dockefile
./base.sh -e ${EFUREPO} -w ${WRITERREPO}

#./efu.dockerfile
buildah unshare ./efu.sh -e ${EFUREPO}

#./writer.dockerfile
buildah unshare ./writer.sh -w ${WRITERREPO}

#./forwarder.dockerfile
./forwarder.sh
