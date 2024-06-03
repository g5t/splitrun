#!/usr/bin/env -S podman build . -v ${WRITERREPO}:/opt/repo:Z -v ${WRITERBUILD}:/opt/build:Z --tag=splitrun/writer:v1 --file
FROM splitrun/base:v1
# Configure, build, install
RUN cd /opt/build/ && cmake -S /opt/repo -B /opt/build && cmake --build /opt/build -j &&\
 mkdir /writer && cp -r /opt/build/bin /writer/. && cp -r /opt/build/lib /writer/.


FROM busybox:glibc
# Copy in all binaries
COPY --from=0 /writer/bin/* /usr/local/bin/
## Copy in the Conan built shared libraries
COPY --from=0 /writer/lib/*.so* /lib64/
# Copy over system libraries, identified with
# LD_TRACE_LOADED_OBJECTS=1 kakfa-to-nexus
COPY --from=0 /lib64/libcrypt.so* /lib64/
COPY --from=0 /lib64/libgcc_s.so* /lib64/
COPY --from=0 /lib64/libstdc++.so* /lib64/

