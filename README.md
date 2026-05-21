# Agent-VM

I run my AI coding agents in isolated containers, for sandboxing reasons.
Each agent is only able to see the current working directory and a few hand-picked
paths from my HOME. See my [aibox script]().

However there is one big limitation: agents can't build containers or do more privileged
operations. This `Agent-VM` works around this.

It provides a bootc-based VM with:
- SSH access (key-based auth only)
- Passwordless `sudo` for the `agent` user
- [coreos-assembler (cosa)](https://github.com/coreos/coreos-assembler) available via a wrapper script
- Container tools: `podman`, `buildah`, `skopeo`
- Compilers and build essentials: `gcc`, `g++`, `make`, `cmake`, `python3`
- Common CLI utilities: `git`, `curl`, `jq`, `vim`, `tmux`, `htop`, etc.

On first boot, a systemd service pulls the cosa container image and installs
a `cosa` wrapper at `/usr/local/bin/cosa`. Agents can then run `cosa` commands
directly from any working directory.

## Running the VM

The host (Bazzite) doesn't ship `qemu-system-x86_64`, so the VM runs
inside a toolbox container via a Podman quadlet.

### Setup

```bash
mkdir -p ~/.local/share/agent-vm
cp <qcow2-image> ~/.local/share/agent-vm/disk.qcow2
mkdir -p ~/.config/containers/systemd
cp agent-vm.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start agent-vm.service
```

To have it start automatically at boot (before login), enable lingering:
```bash
loginctl enable-linger $USER
```

### Connecting

```bash
ssh -i ~/.ssh/ia-agent -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9922 agent@localhost
```

The VM always boots from a clean state thanks to `-snapshot`.
Check the logs with `journalctl --user -u agent-vm`.

## Container image

The container image is automatically built and pushed to GHCR on every push
to `main`:

```
ghcr.io/jbtrystram/agent-vm:latest
```

You can also pull a specific version by its Git SHA tag.

## Create the initial VM snapshot

We use bootc as a base image. The QCOW2 disk image can be created
with [bootc-image-builder](https://github.com/osbuild/bootc-image-builder).

First, edit `config.toml` and replace the placeholder SSH key with your
actual public key:
```toml
[[customizations.user]]
name = "agent"
key = "ssh-ed25519 AAAA... you@host"
groups = ["wheel"]
```

Then build the QCOW2 image:
```bash
sudo podman run --rm --privileged \
   -v /var/lib/containers/storage:/var/lib/containers/storage \
   -v .:/srv \
   ghcr.io/osbuild/image-builder-cli:latest \
   build qcow2 \
   --bootc-ref ghcr.io/jbtrystram/agent-vm:latest \
   --blueprint /srv/config.toml \
   --output-dir /srv/
```

The resulting QCOW2 image will be written to `./output/qcow2/disk.qcow2`.
The `agent` user will have your SSH key baked in and ready to use.

