# Agent-VM

I run my AI coding agents in isolated containers, for sandboxing reasons.
Each agent is only able to see the current working directory and a few hand-picked
paths from my HOME. See my [aibox script](https://github.com/jbtrystram/dotfiles/blob/main/dot_local/bin/executable_aibox).

However there is one big limitation: agents can't build containers or do more privileged
operations. This `Agent-VM` setup works around this.

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

## Create the initial VM snapshot

First, build the container, as root because image-builder needs
root privileges:
```
sudo podman build . -t localhost/agent-vm
```
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
   --bootc-ref localhost/agent-vm\
   --blueprint /srv/config.toml \
   --output-dir /srv/
   --output-name ia-vm
```

The resulting QCOW2 image will be written to `./ia-vm.qcow2`.
The `agent` user will have your SSH key baked in and ready to use.

## Running the VM

 The VM runs inside a container so we don't requires to have any other dependencies
than `/dev/kvm` on the host.

### Setup

```bash
mkdir -p ~/.local/share/agent-vm
cp <qcow2-image> ~/.local/share/agent-vm/disk.qcow2
mkdir -p ~/.config/containers/systemd
cp agent-vm.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start agent-vm.service
```

### Connecting

```bash
ssh -i ~/.ssh/ia-agent -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9922 agent@localhost
```

Or add this to your `~/.ssh/config`:
```
Host agent-vm
    HostName localhost
    Port 9922
    User agent
    IdentityFile ~/.ssh/ia-agent
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

Then connect with `ssh agent-vm`.

The VM always boots from a known clean state thanks to `-snapshot`.
Check the logs with `journalctl --user -u agent-vm`.
