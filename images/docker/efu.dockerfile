#!/usr/bin/env -S podman build . -v ${EFUREPO}/:/opt/repo:Z -v ${EFUBUILD}/:/opt/build:Z --tag=splitrun/efu:v1 --file
FROM splitrun/base:v1
# Configure, build, install
RUN cd /opt/build/ && cmake -S /opt/repo -B /opt/build && cmake --build /opt/build --target install -j

FROM busybox:glibc
# Copy in all binaries
COPY --from=0 /usr/local/bin /usr/local/bin
# Copy in the Conan built shared libraries
COPY --from=0 /usr/local/lib/*.so* /lib64/
# Copy over system libraries, identified with
# LD_TRACE_LOADED_OBJECTS=1 bifrost
COPY --from=0 /lib64/libcrypt.so* /lib64/
COPY --from=0 /lib64/libgcc_s.so* /lib64/
COPY --from=0 /lib64/libstdc++.so* /lib64/

