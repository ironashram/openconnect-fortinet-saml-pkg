#!/usr/bin/env bash
#
# Build openconnect-fortinet-saml .deb for the requested Ubuntu / Debian release.
#
# Usage:
#   ./build-deb.sh [ubuntu:24.04]            # default = ubuntu:24.04
#   ./build-deb.sh ubuntu:25.10
#   ./build-deb.sh debian:bookworm           # any apt-based image works
#
# Output:
#   dist/<image-tag-sanitised>/*.deb
#
# Requires: docker OR podman. Pulls the upstream source from the configured
# GitHub repo and overlays debian/ from this directory. No host build deps
# needed beyond the container engine.

set -euo pipefail

IMAGE="${1:-ubuntu:24.04}"
REPO_URL="${OPENCONNECT_SAML_REPO:-https://github.com/ironashram/openconnect-fortinet-saml.git}"
REPO_REF="${OPENCONNECT_SAML_REF:-master}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
TAG_SAFE=$(echo "${IMAGE}" | tr '/:' '--')
OUT_DIR="${REPO_ROOT}/dist/${TAG_SAFE}"

mkdir -p "${OUT_DIR}"

if command -v docker >/dev/null 2>&1; then
	ENGINE=docker
elif command -v podman >/dev/null 2>&1; then
	ENGINE=podman
else
	echo "neither docker nor podman found in PATH" >&2
	exit 2
fi

echo ">>> building openconnect-fortinet-saml for ${IMAGE} using ${ENGINE}"
echo ">>> source: ${REPO_URL} @ ${REPO_REF}"
echo ">>> output: ${OUT_DIR}"

"${ENGINE}" run --rm \
	-v "${SCRIPT_DIR}/debian:/pkg/debian:ro" \
	-v "${OUT_DIR}:/out" \
	-e REPO_URL="${REPO_URL}" \
	-e REPO_REF="${REPO_REF}" \
	"${IMAGE}" \
	bash -euxc '
		export DEBIAN_FRONTEND=noninteractive
		apt-get update
		apt-get install -y --no-install-recommends \
			git \
			ca-certificates \
			build-essential \
			devscripts \
			equivs \
			fakeroot \
			lsb-release

		cd /tmp
		git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" src
		cd src
		# debian/ from this packaging repo overlays the upstream source.
		cp -r /pkg/debian ./debian

		# Bump the changelog with a distro-specific revision suffix so the
		# resulting .deb is named e.g. "_1.0.0-1ubuntu24.04_amd64.deb" rather
		# than just "_1.0.0-1_amd64.deb" (avoids collisions when the same
		# version is built against multiple Ubuntu / Debian releases).
		export DEBEMAIL="sysdadmin@m1k.cloud"
		export DEBFULLNAME="Michele Palazzi"
		DISTRO=$(lsb_release -is | tr "[:upper:]" "[:lower:]")
		RELEASE=$(lsb_release -rs)
		CODENAME=$(lsb_release -cs)
		BASE_VERSION=$(dpkg-parsechangelog -S Version)
		NEW_VERSION="${BASE_VERSION}${DISTRO}${RELEASE}"
		dch -v "${NEW_VERSION}" --distribution "${CODENAME}" \
		    "Automated build for ${DISTRO} ${RELEASE}"

		mk-build-deps -i -r -t "apt-get -y --no-install-recommends"

		dpkg-buildpackage -us -uc -b

		# Built artifacts land in /tmp (parent of source dir).
		cp ../*.deb ../*.buildinfo ../*.changes /out/ 2>/dev/null || true
		ls -la /out/
	'

echo ">>> done. artifacts in ${OUT_DIR}:"
ls -la "${OUT_DIR}"
