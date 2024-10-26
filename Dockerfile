FROM alpine AS build-go
RUN apk add --no-cache git go make
RUN git clone https://github.com/amnezia-vpn/amneziawg-go.git
RUN cd amneziawg-go && make

FROM alpine AS build-c
RUN apk add --no-cache git build-base linux-headers
RUN git clone https://github.com/amnezia-vpn/amneziawg-tools.git
RUN cd amneziawg-tools/src && make

FROM alpine AS build-node
RUN apk add --no-cache git npm
RUN git clone https://github.com/w0rng/amnezia-wg-easy.git
RUN cd amnezia-wg-easy/src && npm ci --omit=dev

# ---

FROM alpine AS run
RUN apk add --no-cache bash nodejs dpkg iptables iptables-legacy
RUN update-alternatives \
  --install /sbin/iptables iptables /sbin/iptables-legacy 10 \
  --slave /sbin/iptables-restore iptables-restore /sbin/iptables-legacy-restore \
  --slave /sbin/iptables-save iptables-save /sbin/iptables-legacy-save

COPY --from=build-go /amneziawg-go/amneziawg-go /usr/local/bin
COPY --from=build-c /amneziawg-tools/src/wg /usr/local/bin
COPY --from=build-c /amneziawg-tools/src/wg-quick/linux.bash /usr/local/bin/wg-quick
RUN mkdir /etc/amnezia && ln -s /etc/wireguard /etc/amnezia/amneziawg
RUN ln -s wg /usr/local/bin/awg

COPY --from=build-node /amnezia-wg-easy/src/wgpw.sh /usr/local/bin/wgpw
COPY --from=build-node /amnezia-wg-easy/src /app

WORKDIR /app
ENV DEBUG=Server,WireGuard
CMD ["node", "server.js"]
