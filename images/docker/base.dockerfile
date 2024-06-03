#!/usr/bin/env -S podman build . -v ${EFUREPO}/conanfile.txt:/opt/efu.txt:Z -v ${WRITERREPO}/conanfile.txt:/opt/writer.txt:Z --tag=splitrun/base:v1 --file
FROM almalinux:9
RUN dnf -y install glibc-minimal-langpack libstdc++ cmake python3-pip git gcc gcc-c++ &&\
 python3 -m pip install "conan<2" &&\
 conan profile new --detect default &&\
 conan config install https://github.com/ess-dmsc/conan-configuration.git &&\
 conan profile update settings.compiler.libcxx=libstdc++11 default
RUN conan install /opt/efu.txt -pr default -g=cmake --build=outdated --no-imports
RUN conan install /opt/writer.txt -pr default -g=cmake --build=outdated --no-imports
