FROM ubuntu:24.04 AS builder

RUN export DEBIAN_FRONTEND=noninteractive \
	&& ln -fs /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

RUN apt-get update && apt-get install -y --no-install-recommends \
	git cmake curl zip unzip tar automake ca-certificates build-essential \
	libglew-dev libx11-dev autoconf libtool pkg-config tzdata libssl3 \
	python3 python3-pip python3-setuptools ninja-build meson \
	flex bison gperf nasm yasm \
	&& dpkg-reconfigure --frontend noninteractive tzdata \
	&& apt-get clean && apt-get autoclean

WORKDIR /opt
COPY vcpkg.json /opt
RUN vcpkgCommitId=$(grep '.builtin-baseline' vcpkg.json | awk -F: '{print $2}' | tr -d '," ') \
	&& echo "vcpkg commit ID: $vcpkgCommitId" \
	&& git clone https://github.com/Microsoft/vcpkg.git \
	&& cd vcpkg \
	&& git checkout $vcpkgCommitId \
	&& ./bootstrap-vcpkg.sh

WORKDIR /opt/vcpkg
COPY vcpkg.json /opt/vcpkg/
ENV VCPKG_BINARY_SOURCES=clear
RUN /opt/vcpkg/vcpkg install --triplet=x64-linux --debug

COPY ./ /otclient/
WORKDIR /otclient/build

RUN cmake -DCMAKE_TOOLCHAIN_FILE=/opt/vcpkg/scripts/buildsystems/vcpkg.cmake ..
RUN make -j$(nproc)

FROM ubuntu:24.04

RUN apt-get update; \
	apt-get install -y \
	libluajit-5.1-dev \
	libglew-dev \
	libx11-dev \
	libopenal1 \
	libopengl0 \
	&& apt-get clean && apt-get autoclean

COPY --from=builder /otclient /otclient
COPY ./data/ /otclient/data/.
COPY ./mods/ /otclient/mods/.
COPY ./modules/ /otclient/modules/.
COPY ./init.lua /otclient/.
WORKDIR /otclient
CMD ["./otclient"]
