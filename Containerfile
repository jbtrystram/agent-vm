FROM quay.io/fedora/fedora-bootc:44

# -- System tooling (dev-focused) -----------------------------------------------
COPY packages.txt /tmp/packages.txt
RUN <<EORUN
    dnf install -y $(grep -v '^#' /tmp/packages.txt | grep -v '^$')
    dnf clean all
    rm -rf /var/cache /tmp/packages.txt
    rm -rf /run/dnf /var/lib/dnf
    rm -f /var/log/dnf5.log
EORUN

# -- SSH server ------------------------------------------------------------------
# bcvk injects SSH keys via systemd credentials (-K flag).
# We just need sshd running and configured for pubkey auth.
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
# sysusers.d for declarative user creation (bootc-native)
RUN <<EORUN
cat <<EOF > /usr/lib/sysusers.d/agent-vm.conf
u agent 1000 "Agent user" /var/home/agent /bin/bash
m agent wheel
EOF

cat <<EOF > /usr/lib/tmpfiles.d/agent-vm.conf
d /var/home/agent 0700 agent agent - -
EOF

cat <<EOF > /etc/sudoers.d/agent
agent ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/agent
EORUN

# -- coreos-assembler (cosa) wrapper --------------------------------------------
# The wrapper invokes cosa as a container. Agents can pull the image on first use.
COPY cosa /usr/local/bin/cosa

# -- Lint -----------------------------------------------------------------------
RUN bootc container lint

# -- Metadata -------------------------------------------------------------------
LABEL description="Bootc-based VM for AI agents (launched via bcvk)" \
      maintainer="jbtrystram"
