#!/bin/bash

set -eux

ETCD_VER=v3.6.0-rc.5
ARCH=$(dpkg --print-architecture)

# Install etcd
## choose either URL
GOOGLE_URL=https://storage.googleapis.com/etcd
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GOOGLE_URL}

rm -f /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz
rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz
tar xzvf /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz -C /tmp/etcd-download-test --strip-components=1 --no-same-owner
rm -f /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz

mv /tmp/etcd-download-test/etcd /usr/local/bin/etcd
mv /tmp/etcd-download-test/etcdctl /usr/local/bin/etcdctl
mv /tmp/etcd-download-test/etcdutl /usr/local/bin/etcdutl
chmod +x /usr/local/bin/etcd /usr/local/bin/etcdctl /usr/local/bin/etcdutl


# Configure etcd
mkdir -p /etc/etcd /var/lib/etcd /var/lib/kubernetes/pki
chmod 700 /var/lib/etcd
cp /vagrant/certs/{ca.crt,kube-api-server.key,kube-api-server.crt} \
  /etc/etcd/


cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name controller \
  --initial-advertise-peer-urls http://127.0.0.1:2380 \
  --listen-peer-urls http://127.0.0.1:2380 \
  --listen-client-urls http://127.0.0.1:2379 \
  --advertise-client-urls http://127.0.0.1:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster controller=http://127.0.0.1:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start the etcd Server
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd

# Wait for etcd to start
sleep 5

# Check the etcd Server
etcdctl member list
# ETCDCTL_API=3 etcdctl member list \
#   --endpoints=https://127.0.0.1:2379 \
#   --cacert=/etc/etcd/ca.crt \
#   --cert=/etc/etcd/etcd.crt \
#   --key=/etc/etcd/etcd.key
