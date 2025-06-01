#!/bin/bash

set -eux

ARCH=$(dpkg --print-architecture)
HOME_CONFIG=/home/vagrant/k8sconfigs
CERT_DIR=$HOME_CONFIG/certs
CONFIG_DIR=$HOME_CONFIG/configs
KUBECONFIG_DIR=$HOME_CONFIG/kubeconfigs
UNIT_DIR=$HOME_CONFIG/units

# Install the OS dependencies
apt-get update
apt-get -y install socat conntrack ipset kmod


# Download etcd

ETCD_VER=v3.6.0-rc.5

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

## Create installation directories:
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
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


# Configure reference CNI plugin

## Create `bridge` network configuration file:
# cp $CONFIG_DIR/{10-bridge.conf,99-loopback.conf} /etc/cni/net.d/
HOSTNAME=$(hostname -s)

cp $CONFIG_DIR/99-loopback.conf /etc/cni/net.d/
cp $CONFIG_DIR/10-bridge.$HOSTNAME.conf /etc/cni/net.d/10-bridge.conf
cp $CONFIG_DIR/kubelet-config.yaml /etc/cni/net.d/kubelet-config.yaml

## To ensure network traffic crossing the CNI `bridge` network is processed by `iptables`, 
## load and configure the `br-netfilter` kernel module
# modprobe br-netfilter
# echo "br-netfilter" >> /etc/modules-load.d/modules.conf
# echo "net.bridge.bridge-nf-call-iptables = 1" \
#   >> /etc/sysctl.d/kubernetes.conf
# echo "net.bridge.bridge-nf-call-ip6tables = 1" \
#   >> /etc/sysctl.d/kubernetes.conf
# sysctl -p /etc/sysctl.d/kubernetes.conf


# Configure containerd

## Install `containerd` configuration files:
mkdir -p /etc/containerd/
cp $CONFIG_DIR/containerd-config.toml /etc/containerd/config.toml
cp $UNIT_DIR/containerd.service /etc/systemd/system/


# Configure Kubelet
cp $CONFIG_DIR/kubelet-config.yaml /var/lib/kubelet/
cp $KUBECONFIG_DIR/$HOSTNAME.kubeconfig /var/lib/kubelet/kubeconfig
cp $CERT_DIR/ca.crt /var/lib/kubelet/
cp $CERT_DIR/$HOSTNAME.crt /var/lib/kubelet/kubelet.crt
cp $CERT_DIR/$HOSTNAME.key /var/lib/kubelet/kubelet.key
cp $UNIT_DIR/kubelet.service /etc/systemd/system/


# Configure Kubernetes Proxy
cp $CONFIG_DIR/kube-proxy-config.yaml $KUBECONFIG_DIR/kube-proxy.kubeconfig /var/lib/kube-proxy/
cp $UNIT_DIR/kube-proxy.service /etc/systemd/system/


# Start the Worker Services

systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy

# Wait for the kubelet to start
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
