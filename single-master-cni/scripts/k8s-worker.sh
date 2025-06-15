#!/bin/bash

set -eux

# Arguments:
# $1 - Pod CIDR
# $2 - Service CIDR
POD_CIDR=$1
SERVICE_CIDR=$2

if [ -z "$POD_CIDR" ]; then
  POD_CIDR="10.244.0.0/16"
fi

if [ -z "$SERVICE_CIDR" ]; then
  SERVICE_CIDR="10.252.0.0/16"
fi

ARCH=$(dpkg --print-architecture)
HOME_CONFIG=/home/vagrant/k8sconfigs
CERT_DIR=$HOME_CONFIG/certs
CONFIG_DIR=$HOME_CONFIG/configs
KUBECONFIG_DIR=$HOME_CONFIG/kubeconfigs
UNIT_DIR=$HOME_CONFIG/units

# Install the OS dependencies
# socat: NECESSARY - Used by Kubernetes for port forwarding functionality and some networking operations.
# conntrack: NECESSARY - Required for connection tracking in iptables, which kube-proxy uses for service implementation.
# ipvsadm: OPTIONAL - Only needed if you're using IPVS mode for kube-proxy (your config uses iptables mode).
# ipset: NECESSARY - Used by kube-proxy for efficient IP address management in iptables rules.
# kmod: NECESSARY - Required for loading kernel modules like br_netfilter, which is essential for container networking.
if [ -f /etc/debian_version ]; then
  apt-get update
  apt-get -y install socat conntrack ipvsadm ipset kmod
elif [ -f /etc/redhat-release ] || [ -f /etc/fedora-release ]; then
  yum install -y socat conntrack-tools ipset ipvsadm
fi

# Download etcd

ETCD_VER=v3.6.1

## choose either URL
GOOGLE_URL=https://storage.googleapis.com/etcd
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GOOGLE_URL}

rm -f /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz
rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz
tar xzvf /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz -C /tmp/etcd-download-test --strip-components=1 --no-same-owner
rm -f /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz

mv /tmp/etcd-download-test/etcdctl /usr/local/bin/etcdctl
rm -rf /tmp/etcd-download-test/
chmod +x /usr/local/bin/etcdctl

# Download CNI plugins

CNI_PLUGINS_VER=v1.7.1

wget -q --show-progress \
  --https-only \
  --timestamping \
  -P /tmp/ \
  https://github.com/containernetworking/plugins/releases/download/$CNI_PLUGINS_VER/cni-plugins-linux-$ARCH-$CNI_PLUGINS_VER.tgz

mkdir -p /opt/cni/bin/
tar -xvf /tmp/cni-plugins-linux-$ARCH-$CNI_PLUGINS_VER.tgz \
    -C /opt/cni/bin/
chmod +x /opt/cni/bin/*

# Install components

K8S_VER=v1.33.1
CRI_VER=v1.33.0
CONTAINERD_VER=2.1.0
RUNC_VER=v1.3.0

## Create installation and connfiguration directories:
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kubelet/pki \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/lib/kubernetes/pki \
  /var/run/kubernetes

cat <<EOF > /tmp/downloads.txt
https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRI_VER/crictl-$CRI_VER-linux-$ARCH.tar.gz
https://dl.k8s.io/$K8S_VER/bin/linux/$ARCH/kube-proxy
https://dl.k8s.io/$K8S_VER/bin/linux/$ARCH/kubectl
https://dl.k8s.io/$K8S_VER/bin/linux/$ARCH/kubelet
https://github.com/opencontainers/runc/releases/download/$RUNC_VER/runc.$ARCH
https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VER/containerd-$CONTAINERD_VER-linux-$ARCH.tar.gz
EOF

wget -q --show-progress \
  --https-only \
  --timestamping \
  -P /tmp/ \
  -i /tmp/downloads.txt

tar -xvf /tmp/crictl-$CRI_VER-linux-${ARCH}.tar.gz \
    -C /tmp/
tar -xvf /tmp/containerd-$CONTAINERD_VER-linux-${ARCH}.tar.gz \
    --strip-components 1 \
    -C /tmp/

mv /tmp/{crictl,kube-proxy,kubelet,kubectl} \
    /usr/local/bin/
mv /tmp/runc.$ARCH /usr/local/bin/runc
chmod +x /usr/local/bin/{crictl,kube-proxy,kubelet,kubectl,runc}
mv /tmp/{containerd,containerd-shim-runc-v2,containerd-stress} /bin/
chmod +x /bin/{containerd,containerd-shim-runc-v2,containerd-stress}


# Configure the CNI plugin

## Add a route for the service CIDR

### IMPORTANT: Tell the Linux kernel that traffic destined 
### for the service CIDR should be handled locally. This 
### allows kube-proxy's iptables rules to intercept and 
### redirect this traffic to the appropriate destinations.

### Add route immediately
ip route add $SERVICE_CIDR dev lo
### Configure persistent route
if [ -f /etc/debian_version ]; then
  PERSIST_FILE="/etc/network/interfaces.d/route-lo"
  echo -e "auto lo\niface lo inet loopback\n    post-up ip route add $SERVICE_CIDR dev lo" > $PERSIST_FILE
elif [ -f /etc/redhat-release ] || [ -f /etc/fedora-release ]; then
  ROUTE_FILE="/etc/sysconfig/network-scripts/route-lo"
  echo "$SERVICE_CIDR dev lo" > $ROUTE_FILE
fi

## To ensure network traffic crossing the CNI `bridge` network is processed by `iptables`, 
## load and configure the `br-netfilter` kernel module
modprobe br-netfilter
echo "br-netfilter" >> /etc/modules-load.d/modules.conf
echo "net.bridge.bridge-nf-call-iptables = 1" \
  >> /etc/sysctl.d/kubernetes.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" \
  >> /etc/sysctl.d/kubernetes.conf
sysctl -p /etc/sysctl.d/kubernetes.conf


# Configure containerd

## Install the `containerd` configuration files:
mkdir -p /etc/containerd/
cp $CONFIG_DIR/containerd-config.toml /etc/containerd/config.toml
cp $UNIT_DIR/containerd.service /etc/systemd/system/


# Configure the Kubelet

## Configure kubelet
cp $CONFIG_DIR/kubelet-config.yaml /var/lib/kubelet/
cp $KUBECONFIG_DIR/$HOSTNAME.kubeconfig /var/lib/kubelet/kubeconfig
cp $KUBECONFIG_DIR/tls-bootstrap.kubeconfig /var/lib/kubelet/
cp $CERT_DIR/ca.crt /var/lib/kubelet/
cp $CERT_DIR/$HOSTNAME.crt /var/lib/kubelet/kubelet.crt
cp $CERT_DIR/$HOSTNAME.key /var/lib/kubelet/kubelet.key
cp $UNIT_DIR/kubelet.$HOSTNAME.service /etc/systemd/system/kubelet.service


# Configure Kubernetes Proxy

## Copy the certificates
cp $CERT_DIR/{ca.crt,kube-proxy.crt,kube-proxy.key} /var/lib/kubernetes/pki/
chown root:root /var/lib/kubernetes/pki/*
chmod 600 /var/lib/kubernetes/pki/*

## Copy the kube-proxy configuration files
cp $CONFIG_DIR/kube-proxy-config.yaml $KUBECONFIG_DIR/kube-proxy.kubeconfig /var/lib/kube-proxy/
cp $UNIT_DIR/kube-proxy.service /etc/systemd/system/


# Start the Worker Services

systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy

# Wait for kubelet to start
sleep 10

# Verify
for i in containerd kube-proxy kubelet; do
  if systemctl is-active --quiet $i; then
    echo "$i is active"
  else
    echo "$i is not active"
    exit 1
  fi
done
