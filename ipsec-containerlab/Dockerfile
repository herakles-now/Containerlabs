FROM alpine:3.20

RUN apk add --no-cache \
    bash \
    strongswan \
    iproute2 \
    iptables \
    iputils \
    tcpdump \
    curl \
    vim \
    procps \
    busybox-extras \
    && command -v swanctl >/dev/null

# Alpine bundles swanctl in the "strongswan" package; a separate
# "strongswan-swanctl" package does not exist in Alpine 3.20.

CMD ["sleep", "infinity"]
