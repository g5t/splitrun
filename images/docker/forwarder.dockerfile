#!/usr/bin/env -S podman build . --tag=splitrun/forwarder:v1 --file
# We need python<3.12 for p4p and non-muslc for epicscorelibs :(
# So alpine is not a viable base image
FROM almalinux:9
RUN dnf -y install python3 python3-pip git &&\
 python3 -m pip install\
  git+https://github.com/g5t/ess-forwarder.git@explicit-submodules\
  git+https://github.com/g5t/mccode-plumber.git@v0.3.7\
 &&\
 dnf -y remove python3-pip git &&\
 dnf clean all &&\
 rm -rf /var/cache/yum
COPY entrypoints/entrypoint-forwarder.sh /entrypoint.sh
CMD ["sh", "/entrypoint.sh"]