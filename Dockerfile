FROM alpine AS build-go
RUN apk add --no-cache git go make
RUN git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-go.git
RUN cd amneziawg-go && make

FROM alpine AS build-c
RUN apk add --no-cache git build-base linux-headers
RUN git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-tools.git
RUN cd amneziawg-tools/src && make

FROM alpine AS build-node
RUN apk add --no-cache npm
WORKDIR /build
COPY src/package.json src/package-lock.json ./src/
RUN cd src && npm ci --omit=dev
COPY src ./src

# ---

FROM alpine AS run
RUN apk add --no-cache bash nodejs dpkg iptables iptables-legacy \
  && set -eux \
  && IPTABLES_BIN="$(command -v iptables)" \
  && IPTABLES_RESTORE_BIN="$(command -v iptables-restore)" \
  && IPTABLES_SAVE_BIN="$(command -v iptables-save)" \
  && IPTABLES_LEGACY_BIN="$(command -v iptables-legacy)" \
  && IPTABLES_LEGACY_RESTORE_BIN="$(command -v iptables-legacy-restore)" \
  && IPTABLES_LEGACY_SAVE_BIN="$(command -v iptables-legacy-save)" \
  && update-alternatives \
    --install "${IPTABLES_BIN}" iptables "${IPTABLES_LEGACY_BIN}" 10 \
    --slave "${IPTABLES_RESTORE_BIN}" iptables-restore "${IPTABLES_LEGACY_RESTORE_BIN}" \
    --slave "${IPTABLES_SAVE_BIN}" iptables-save "${IPTABLES_LEGACY_SAVE_BIN}"

COPY --from=build-go /amneziawg-go/amneziawg-go /usr/local/bin
COPY --from=build-c /amneziawg-tools/src/wg /usr/local/bin
COPY --from=build-c /amneziawg-tools/src/wg-quick/linux.bash /usr/local/bin/wg-quick
RUN mkdir /etc/amnezia && ln -s /etc/wireguard /etc/amnezia/amneziawg
RUN ln -s wg /usr/local/bin/awg

COPY --from=build-node /build/src/wgpw.sh /usr/local/bin/wgpw
COPY --from=build-node /build/src /app

WORKDIR /app
ENV DEBUG=Server,WireGuard
CMD ["node", "server.js"]
