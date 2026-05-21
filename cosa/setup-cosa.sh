#!/bin/bash
# setup-cosa.sh — Runs at boot to pull the coreos-assembler container image.
# The cosa wrapper script is baked into the image at /usr/local/bin/cosa.

set -euo pipefail

COSA_IMAGE="quay.io/coreos-assembler/coreos-assembler:latest"

echo "setup-cosa: pulling ${COSA_IMAGE}..."
podman pull "${COSA_IMAGE}"
echo "setup-cosa: done."
