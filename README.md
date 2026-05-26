# Agent-VM

I run my AI coding agents in isolated containers, for sandboxing reasons.
Each agent is only able to see the current working directory and a few hand-picked
paths from my HOME. See my [aibox script](https://github.com/jbtrystram/dotfiles/blob/main/dot_local/bin/executable_aibox).

However there is one big limitation: agents can't build containers or do more privileged
operations. This `Agent-VM` setup works around this.

It provides a VM with:
- SSH access (key-based auth only)
- Passwordless `sudo` for the `fedora` user
- [coreos-assembler (cosa)](https://github.com/coreos/coreos-assembler) available via a wrapper script
- Container tools: `podman`, `buildah`, `skopeo`
- Compilers and build essentials: `gcc`, `g++`, `make`, `cmake`, `python3`
- Common CLI utilities: `git`, `curl`, `jq`, `vim`, `tmux`, `htop`, etc.

## Initial setup

### 1. Download the Fedora Cloud image

```bash
IMAGE_URL=$(curl -s https://fedoraproject.org/releases.json | \
  jq -r '[.[] | select(.variant=="Cloud" and .arch=="x86_64" and (.link | endswith(".qcow2")))] | sort_by(.version | tonumber) | last | .link')

export IMAGE=$(basename $IMAGE_URL)
curl -L  $IMAGE_URL -o $IMAGE
```

### 2. Resize the disk

The stock image is small. Resize it so there's room to work:
```bash
qemu-img resize $IMAGE 40G
```

### 3. Add your SSH public key to cloud-init

Edit `cloud-init/user-data` and replace the placeholder `ssh_authorized_keys`
entry with your actual public key:
```yaml
ssh_authorized_keys:
  - ssh-ed25519 AAAA...your-actual-key... user@host
```

### 4. Build the cloud-init seed ISO

Generate a seed ISO from the cloud-init config:
```bash
genisoimage -output seed.iso -volid cidata -joliet -rock cloud-init/user-data cloud-init/meta-data
```

### 5. Provision the VM (one-time boot)

Boot the image **without** `-snapshot`, attaching the seed ISO so cloud-init
runs, installs packages, configures sshd, sets up cosa, and writes your SSH
key to the `fedora` user's `authorized_keys`:
```bash
qemu-system-x86_64 \
    -M accel=kvm \
    -cpu host \
    -smp 4 \
    -m 4096 \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -nographic \
    -nic user,hostfwd=tcp::9922-:22 \
    -drive file=$IMAGE,if=virtio \
    -drive file=seed.iso,if=virtio,format=raw
```

Wait for cloud-init to finish (you can watch the console output or SSH in
once sshd is up). Then shut the VM down -- this QCOW2 is now your golden
base image.

### 6. Install the Quadlet

```bash
mkdir -p ~/.local/share/agent-vm
mv $IMAGE ~/.local/share/agent-vm/disk.qcow2
mkdir -p ~/.config/containers/systemd
cp agent-vm.container ~/.config/containers/systemd/
cp launch-vm.sh ~/.local/bin/launch-vm-agent.sh
systemctl --user daemon-reload
systemctl --user start agent-vm.service
```

## SSH key

The SSH public key is baked into the golden image by cloud-init during
provisioning (step 3 above). Since the VM runs with `-snapshot`, the image
is never modified -- the key persists across reboots without any per-boot
injection. To change the key, update `cloud-init/user-data`, rebuild the
seed ISO, and re-provision the golden image.

## Connecting

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9922 fedora@localhost
```

Or add this to your `~/.ssh/config`:
```
Host agent-vm
    HostName localhost
    Port 9922
    User fedora
    IdentityFile ~/.ssh/ia-agent
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

Then connect with `ssh agent-vm`.

The VM always boots from a known clean state thanks to `-snapshot`.
Check the logs with `journalctl --user -u agent-vm`.
