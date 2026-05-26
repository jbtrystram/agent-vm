#!/bin/bash
# Launch the agent VM with QEMU.
#
# The SSH public key is baked into the golden image via cloud-init during
# provisioning, so no per-boot key injection is needed. Since the VM runs
# with -snapshot, the image always boots from a clean state.

set -euo pipefail

VM_DIR="${VM_DIR:-/vm}"

exec qemu-system-x86_64 \
    -M accel=kvm \
    -cpu host \
    -smp 4 \
    -m 4096 \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -nographic \
    -snapshot \
    -nic user,hostfwd=tcp:0.0.0.0:9922-:22 \
    "${VM_DIR}/disk.qcow2"
