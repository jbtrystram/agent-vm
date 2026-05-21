---
name: privileged-vm
description: Access a Fedora VM to execute any operation.
---

# Skill: Agent VM

Use this skill when you need to perform privileged operations that are
not possible inside the sandboxed agent container. This includes:

- Building container images (`podman build`, `buildah`)
- Running containers (`podman run`)
- Running coreos-assembler (`cosa`) commands
- Any task requiring root-level access

## Connecting

The VM is always running on the host. Connect via SSH:

```bash
ssh -i ~/.ssh/ia-agent -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9922 agent@localhost
```

- Port: **9922**
- User: **agent**
- Host: **localhost**
- Key: **~/.ssh/ia-agent**

The `agent` user has passwordless `sudo`.

## Always create a working directory

This VM is shared with multiple agents. Make sure to create you own workspace.
The worksapce should be named after the directory the agent is running into.

## Running commands

You can run commands non-interactively:

```bash
ssh -i ~/.ssh/ia-agent -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9922 agent@localhost '<command>'
```

For example:

```bash
# Build a container image
ssh -i ~/.ssh/ia-agent -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9922 agent@localhost 'podman build -t myimage /path/to/context'

# Run cosa
ssh -i ~/.ssh/ia-agent -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9922 agent@localhost 'cd /srv/workdir && cosa fetch && cosa build'

# Run anything as root
ssh -i ~/.ssh/ia-agent -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9922 agent@localhost 'sudo dnf install -y <package>'
```

## Important notes

- The VM boots from a **snapshot** -- all changes are lost on reboot.
  Do not store persistent data inside the VM. Copy results back to the
  host before disconnecting.
- To copy files to/from the VM, use `scp`:
  ```bash
  scp -i ~/.ssh/ia-agent -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 9922 localfile agent@localhost:/tmp/
  scp -i ~/.ssh/ia-agent -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 9922 agent@localhost:/tmp/result ./
  ```
- The VM has 4 vCPUs and 4GB of RAM.
- `cosa` is available as a wrapper script at `/usr/local/bin/cosa` after
  first boot (it pulls the container image automatically).
