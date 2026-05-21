---
name: privileged-vm
description: Launch an ephemeral Fedora VM to execute privileged operations.
---

# Skill: Agent VM

Use this skill when you need to perform privileged operations that are
not possible inside the sandboxed agent container. This includes:

- Building container images (`podman build`, `buildah`)
- Running containers (`podman run`)
- Running coreos-assembler (`cosa`) commands
- Any task requiring root-level access

## Launching the VM

The VM is managed by a systemd user service. Start it with:

```bash
systemctl --user start agent-vm.service
```

To enable it at boot (started automatically on login):
```bash
systemctl --user enable agent-vm.service
```

Wait a few seconds for the VM to boot, then verify it is reachable:
```bash
bcvk ephemeral ssh ai-vm 'echo ok'
```

## Running commands

Run commands inside the VM non-interactively:
```bash
bcvk ephemeral ssh ai-vm '<command>'
```

For example:
```bash
# Build a container image
bcvk ephemeral ssh ai-vm 'podman build -t myimage /run/virtiofs-mnt-workdir'

# Run cosa
bcvk ephemeral ssh ai-vm 'mkdir ~/cosa && cd ~/cosa && cosa init --force https://github.com/coreos/fedora-coreos-config && cosa fetch && cosa build'

# Run anything as root
bcvk ephemeral ssh ai-vm 'sudo dnf install -y <package>'
```

## Sharing files with the VM

To mount a host directory into the VM, add `--bind` to the `ExecStart`
line in the systemd unit (or use a drop-in override):
```bash
systemctl --user edit agent-vm.service
```
```ini
[Service]
ExecStart=
ExecStart=/usr/bin/bcvk ephemeral run --rm -K --console \
    --bind /path/to/workdir:workdir \
    --name ai-vm ${CONTAINER_IMAGE}
```

Inside the VM, the directory is available at `/run/virtiofs-mnt-workdir`.

If the VM is already running without a bind mount, use `scp` style
transfer via `podman cp`:
```bash
podman cp localfile ai-vm:/path/in/container
```

## Stopping the VM

When done, stop and auto-remove the VM:
```bash
systemctl --user stop agent-vm.service
```

## Important notes

- The VM is **ephemeral** -- all changes are lost when stopped.
- The `agent` user has passwordless `sudo`.
- `cosa` is available at `/usr/local/bin/cosa` (pulls its container image on first use).
- The VM has 4 vCPUs and 4GB of RAM.
