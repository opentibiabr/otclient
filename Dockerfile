# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04 AS dependencies

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND}
ENV TZ=Etc/UTC
ARG VCPKG_FEED_URL
ARG VCPKG_FEED_USERNAME
ARG VCPKG_BINARY_SOURCES
ENV VCPKG_BINARY_SOURCES=${VCPKG_BINARY_SOURCES}

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
	apt-get update && apt-get install -y --no-install-recommends \
	autoconf \
	automake \
	build-essential \
	ca-certificates \
	cmake \
	curl \
	git \
	libgl1-mesa-dev \
	libtool \
	libx11-dev \
	libxcursor-dev \
	libxi-dev \
	libxinerama-dev \
	libxrandr-dev \
	mono-complete \
	ninja-build \
	pkg-config \
	python3 \
	tar \
	tzdata \
	unzip \
	zip \
	&& ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
	&& echo "${TZ}" > /etc/timezone \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /opt
COPY vcpkg.json /opt/vcpkg.json
RUN vcpkgCommitId="$(grep '.builtin-baseline' vcpkg.json | awk -F: '{print $2}' | tr -d ',\" ')" \
	&& echo "vcpkg commit ID: ${vcpkgCommitId}" \
	&& git clone https://github.com/microsoft/vcpkg.git \
	&& cd vcpkg \
	&& git checkout "${vcpkgCommitId}" \
	&& ./bootstrap-vcpkg.sh

WORKDIR /opt/vcpkg_manifest
COPY vcpkg.json /opt/vcpkg_manifest/

RUN --mount=type=secret,id=github_token \
	--mount=type=cache,target=/opt/vcpkg/downloads \
	--mount=type=cache,target=/opt/vcpkg/buildtrees \
	--mount=type=cache,target=/opt/vcpkg/packages \
	--mount=type=cache,target=/root/.cache/vcpkg \
	/bin/bash -euo pipefail -c '\
		nuget_config=""; \
		if [ -s /run/secrets/github_token ] && [ -n "${VCPKG_FEED_URL:-}" ] && [ -n "${VCPKG_FEED_USERNAME:-}" ]; then \
			nuget_auth_token="$(cat /run/secrets/github_token)"; \
			nuget_config="/tmp/nuget.config"; \
			printf "%s\n" \
				"<?xml version=\"1.0\" encoding=\"utf-8\"?>" \
				"<configuration>" \
				"  <packageSources>" \
				"    <add key=\"GitHubPackages\" value=\"${VCPKG_FEED_URL}\" />" \
				"  </packageSources>" \
				"  <packageSourceCredentials>" \
				"    <GitHubPackages>" \
				"      <add key=\"Username\" value=\"${VCPKG_FEED_USERNAME}\" />" \
				"      <add key=\"ClearTextPassword\" value=\"${nuget_auth_token}\" />" \
				"    </GitHubPackages>" \
				"  </packageSourceCredentials>" \
				"  <config>" \
				"    <add key=\"defaultPushSource\" value=\"GitHubPackages\" />" \
				"  </config>" \
				"</configuration>" \
				> "${nuget_config}"; \
			export VCPKG_NUGET_API_KEY="${nuget_auth_token}"; \
			export VCPKG_BINARY_SOURCES="clear;nugetconfig,${nuget_config},readwrite;nugettimeout,1200"; \
		elif [ -n "${VCPKG_BINARY_SOURCES:-}" ]; then \
			echo "Using provided VCPKG_BINARY_SOURCES."; \
		else \
			unset VCPKG_BINARY_SOURCES; \
		fi; \
		/opt/vcpkg/vcpkg install \
			--x-manifest-root=/opt/vcpkg_manifest \
			--x-install-root=/opt/vcpkg_installed \
			--triplet=x64-linux \
			--host-triplet=x64-linux; \
		if [ -n "${nuget_config}" ]; then rm -f "${nuget_config}"; fi'

FROM dependencies AS build

COPY . /srv/
WORKDIR /srv
COPY --from=dependencies /opt/vcpkg_installed /srv/vcpkg_installed

RUN export VCPKG_ROOT=/opt/vcpkg \
	&& cmake --preset linux-release \
		-DTOGGLE_BIN_FOLDER=ON \
		-DOPTIONS_ENABLE_IPO=OFF \
		-DOTCLIENT_BUILD_TESTS=OFF \
		-DBUILD_STATIC_LIBRARY=ON \
		-DVCPKG_MANIFEST_INSTALL=OFF \
		-DVCPKG_INSTALLED_DIR=/srv/vcpkg_installed \
	&& cmake --build --preset linux-release --target otclient

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND}
ENV TZ=Etc/UTC

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
	apt-get update && apt-get install -y --no-install-recommends \
	ca-certificates \
	libgl1 \
	libglu1-mesa \
	libopenal1 \
	libstdc++6 \
	libx11-6 \
	libxcursor1 \
	libxi6 \
	libxinerama1 \
	libxrandr2 \
	tzdata \
	&& ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
	&& echo "${TZ}" > /etc/timezone \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /otclient
COPY --from=build /srv/build/linux-release/bin/ /otclient/
COPY data /otclient/data
COPY mods /otclient/mods
COPY modules /otclient/modules
COPY init.lua otclientrc.lua cacert.pem /otclient/

CMD ["./otclient"]
