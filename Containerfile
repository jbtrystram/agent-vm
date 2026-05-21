FROM quay.io/fedora/fedora-bootc:44

# -- Bootc install defaults -----------------------------------------------------
RUN <<EORUN
cat <<EOF > /usr/lib/bootc/install/00-rootfs.toml
[install.filesystem.root]
type = "xfs"
EOF
EORUN
# -- System tooling (dev-focused) -----------------------------------------------
COPY packages.txt /tmp/packages.txt
RUN <<EORUN
    dnf install -y $(grep -v '^#' /tmp/packages.txt | grep -v '^$')
    dnf clean all
    rm -rf /var/cache /tmp/packages.txt
    rm -rf /run/dnf /var/lib/dnf
    rm /var/log/dnf5.log
EORUN

# -- SSH server configuration ---------------------------------------------------
RUN <<EORUN
    sed -i \
        -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
        -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
        -e 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' \
        -e 's/^#\?UsePAM.*/UsePAM yes/' \
        -e 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' \
        /etc/ssh/sshd_config
    systemctl enable sshd.service
EORUN

# -- Agent user ------------------------------------------------------------------
# Declare the agent user/group via sysusers.d so bootc lint is happy.
# The SSH key is injected at QCOW2 build time via config.toml (blueprint).
RUN <<EORUN
cat <<EOF > /usr/lib/sysusers.d/agent-vm.conf
u agent 1000 "Agent user" /var/home/agent /bin/bash
m agent wheel
EOF

# Ensure the home directory is created at boot
cat <<EOF > /usr/lib/tmpfiles.d/agent-vm.conf
d /var/home/agent 0700 agent agent - -
EOF

# Passwordless sudo for the agent user
cat <<EOF > /etc/sudoers.d/agent
agent ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/agent
EORUN

# -- GRUB: skip boot menu for faster startup ------------------------------------
RUN <<EORUN
cat <<EOF > /etc/default/grub
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
EOF
EORUN

# -- coreos-assembler (cosa) setup at first boot --------------------------------
COPY cosa/cosa /usr/local/bin/cosa
COPY cosa/setup-cosa.sh /usr/local/bin/setup-cosa.sh
COPY cosa/setup-cosa.service /etc/systemd/system/setup-cosa.service
RUN chmod 755 /usr/local/bin/cosa /usr/local/bin/setup-cosa.sh && \
    systemctl enable setup-cosa.service

RUN bootc container lint

# -- Metadata -------------------------------------------------------------------
LABEL description="Bootc-based toolbox VM for AI agents with SSH access" \
      maintainer="jbtrystram"
