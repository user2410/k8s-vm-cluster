#!/bin/bash

set -eux

# Parameters
K8S_VERSION=v1.33

# Constants
ARCH=$(dpkg --print-architecture)
echo ""
echo "##################################"
echo "# RUNNING requirements.sh script #"
echo "##################################"
sleep 2
echo ""
echo ""
echo ""
echo "[TASK 1] update hosts file"
cat /vagrant/scripts/local/hosts >> /etc/hosts
echo "...done..."

# install time synchronization server
echo ""
echo "[TASK 2] install time synchronization server"
apt update
apt-get install ntp -y
apt-get install ntpdate -y
ntpdate -u ntp.ubuntu.com
echo "...done..."

# Forwarding IPv4 and letting iptables see bridged traffic:
echo ""
echo "[TASK 3] Forwarding IPv4 and letting iptables see bridged traffic"
## Add kernel modules
cat << EOF >> /etc/modules-load.d/k8s.conf
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
br_netfilter
nf_conntrack
overlay
EOF
cat /etc/modules-load.d/k8s.conf >> /etc/modules
modprobe overlay
modprobe br_netfilter
systemctl restart systemd-modules-load.service

## Set network tunables
cat <<EOF >> /etc/sysctl.d/kubernetes.conf
net.ipv6.conf.all.disable_ipv6      = 1
net.ipv6.conf.default.disable_ipv6  = 1
net.ipv6.conf.lo.disable_ipv6       = 1
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

## Apply sysctl params without reboot
sysctl --system
echo "...done..."

# Point to Google's DNS server
sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf
service systemd-resolved restart

# Disable swap
echo ""
echo "[TASK 5] Disable swap"
sed -i '/swap/d' /etc/fstab
swapoff -a
echo "...done..."

# # Add repository:
# echo ""
# echo "[TASK 6] Add repository"

# ## Install apt-transport-https pkg
# apt-get update && apt-get install -y apt-transport-https ca-certificates curl gpg

# ## Add Docker repository
# install -m 0755 -d /etc/apt/keyrings
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# chmod a+r /etc/apt/keyrings/docker.gpg
# echo \
#  "deb [arch="$ARCH" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
#  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
#  tee /etc/apt/sources.list.d/docker.list > /dev/null
# echo "...done..."

# ## Add Kubernetes repository
# curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# # Install Containerd:
# echo ""
# echo "[TASK 7] Install Containerd"
# apt-get update
# apt-get install containerd -y

# ## Configuring the systemd cgroup drive:
# ## Creating a containerd configuration file by executing the following command
# mkdir -p /etc/containerd
# containerd config default | tee /etc/containerd/config.toml
# sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml

# ## Restart containerd
# systemctl restart containerd

# # Install Kubernetes components:
# echo ""
# echo "[TASK 8] Install Kubernetes components"

# ## Update apt package index, install kubelet, kubeadm and kubectl, and pin their version:
# apt-get update
# apt-get install -y kubelet kubectl kubeadm
# apt-mark hold kubelet kubeadm kubectl
# systemctl enable --now kubelet
# echo "...done..."

# ## create user kube for compliancy and add to sudoers
# echo ""
# echo "[TASK 9] create user kube for compliancy and add to sudoers"
# useradd -md "/home/kube" -G sudo kube
# echo "kube:kube" | chpasswd
# cp /home/vagrant/.bashrc /home/kube/.bashrc
# chown kube:kube /home/kube/.bashrc
# echo "...done..."

# ## create alias for kubectl command
# echo ""
# echo "[TASK 10] create alias for kubectl command"
# su - vagrant -c 'echo "alias k=kubectl" >> /home/vagrant/.bashrc'
# su - kube -c 'echo "alias k=kubectl" >> /home/kube/.bashrc'
# echo "...done..."
# sleep 5
