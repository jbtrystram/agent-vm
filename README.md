# Agent-VM

I run my AI coding agents in isolated containers, for sandboxing reasons.
Each agent is only able to see the current working directory and a few hand-picked
paths from my HOME. See my [aibox script]().

However there is one big limitation: agents can't build containers or do more privileged
operations. This `Agent-VM` works around this.

It provides a bootc-based VM with:
- Passwordless `sudo` for the `agent` user
- [coreos-assembler (cosa)](https://github.com/coreos/coreos-assembler) available via a wrapper script
- Container tools: `podman`, `buildah`, `skopeo`
- Compilers and build essentials: `make`, `cmake`, `python3`
- Common CLI utilities: `git`, `curl`, `jq`, etc.

## How it works

The VM is launched on demand by agents using
[bcvk](https://bootc.dev/bcvk/) (`bootc virtualization kit`).
bcvk boots the container image directly via virtiofs -- no disk image
creation, no QCOW2, starts in seconds.

Each VM is **ephemeral**: stateless by default, destroyed when stopped.

## Prerequisites

Install `bcvk` on the host:
```bash
dnf install bcvk
# on image mode systems
rpm-ostree install bcvk
```

## Usage

```bash
# Launch the VM
bcvk ephemeral run -d --rm -K \
    --vcpus 4 --memory 4G \
    --name agent-vm \
    ghcr.io/jbtrystram/agent-vm:latest

# SSH in
bcvk ephemeral ssh agent-vm

# Run a command
bcvk ephemeral ssh agent-vm 'podman build -t myimage .'

# Mount a host directory into the VM
bcvk ephemeral run -d --rm -K \
    --vcpus 4 --memory 4G \
    --bind ~/code:code \
    --name agent-vm \
    ghcr.io/jbtrystram/agent-vm:latest
# Available inside VM at /run/virtiofs-mnt-code

# Stop and clean up
podman stop agent-vm
```

## Container image

The container image is automatically built and pushed to GHCR on every push
to `main`:

```
ghcr.io/jbtrystram/agent-vm:latest
```

You can also pull a specific version by its Git SHA tag.
