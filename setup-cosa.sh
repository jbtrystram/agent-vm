#!/bin/bash
# setup-cosa.sh — Runs at boot to ensure coreos-assembler is available.
# Pulls the cosa container image and installs a wrapper script so that
# agents can simply run `cosa <subcommand>`.

set -euo pipefail

COSA_IMAGE="quay.io/coreos-assembler/coreos-assembler:latest"
COSA_WRAPPER="/usr/local/bin/cosa"

echo "setup-cosa: pulling ${COSA_IMAGE}..."
podman pull "${COSA_IMAGE}"

# Install the cosa wrapper script
cat > "${COSA_WRAPPER}" <<'WRAPPER'
#!/bin/bash
# Wrapper around coreos-assembler running in a container.
# Usage: cosa <subcommand> [args...]
#
# The current directory is mounted as the working directory inside the
# container, so run this from your cosa workdir.

set -euo pipefail

COSA_IMAGE="quay.io/coreos-assembler/coreos-assembler:latest"

exec podman run --rm -ti \
    --security-opt label=disable \
    --privileged \
    --uidmap=1000:0:1 --uidmap=0:1:1000 --uidmap=1001:1001:64536 \
    -v "${PWD}:/srv:z" \
    --device /dev/kvm \
    --tmpfs /tmp \
    --name cosa \
    "${COSA_IMAGE}" \
    "$@"
WRAPPER

chmod 755 "${COSA_WRAPPER}"
echo "setup-cosa: wrapper installed at ${COSA_WRAPPER}"
echo "setup-cosa: done."
