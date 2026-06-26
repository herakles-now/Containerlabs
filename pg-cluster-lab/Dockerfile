FROM postgres:18-alpine

# The official postgres image ships the server, client and replication tools in
# /usr/local/bin. We add pgBackRest for backup/WAL archiving, OpenSSH so the
# dedicated repo host can reach the database hosts (pgBackRest off-host mode),
# plus the networking and inspection utilities the lab needs.
RUN apk add --no-cache \
    bash \
    iproute2 \
    iputils \
    iptables \
    tcpdump \
    procps \
    less \
    vim \
    pgbackrest \
    openssh \
    && install -d -m 750 -o postgres -g postgres /var/lib/pgbackrest /var/log/pgbackrest \
    && install -d -m 755 /etc/pgbackrest

# Prepare the postgres user for SSH (pgBackRest off-host mode):
#  - give it a real login shell
#  - unlock the account: the base image locks the password ('!'), which makes
#    sshd reject even pubkey auth ("account is locked"); '*' disables password
#    login while still allowing key-based auth
#  - tighten the world-writable home and relax sshd StrictModes so
#    ~/.ssh/authorized_keys is honoured
RUN sed -i '/^postgres:/ s#[^:]*$#/bin/bash#' /etc/passwd \
    && sed -i 's#^postgres:!:#postgres:*:#' /etc/shadow \
    && chmod 0755 /var/lib/postgresql \
    && ssh-keygen -A \
    && echo "StrictModes no" >> /etc/ssh/sshd_config

# Lab-only passwordless SSH for pgBackRest: one shared keypair baked into the
# image, so every node's postgres user trusts every other node. This is fine for
# a throwaway lab but must NOT be done in production — there you would use
# per-host keys (or TLS) and a locked-down repo host.
RUN install -d -m 700 -o postgres -g postgres /var/lib/postgresql/.ssh \
    && ssh-keygen -t ed25519 -N "" -C clab-pgbackrest -f /var/lib/postgresql/.ssh/id_ed25519 \
    && cp /var/lib/postgresql/.ssh/id_ed25519.pub /var/lib/postgresql/.ssh/authorized_keys \
    && printf 'Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile /dev/null\n    LogLevel ERROR\n' \
        > /var/lib/postgresql/.ssh/config \
    && chmod 600 /var/lib/postgresql/.ssh/* \
    && chown -R postgres:postgres /var/lib/postgresql/.ssh

# Default pgBackRest config baked into the image (a database-host config). On
# pg1/pg2/backup the role-specific file is bind-mounted over it.
COPY pgbackrest/pg1.conf /etc/pgbackrest/pgbackrest.conf

# Drop the postgres entrypoint/cmd: containerlab starts the container idle and
# our start.sh (run via the topology's exec hook) initialises and starts
# PostgreSQL / pgBackRest manually so we control the roles.
ENTRYPOINT []
CMD ["sleep", "infinity"]
