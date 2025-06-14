#!/bin/bash

set -eux

HOME_CONFIG=/home/vagrant/k8sconfigs

# Update hosts file

echo "# Kubernetes Cluster Hosts" >> /etc/hosts
cat $HOME_CONFIG/hosts_addition >> /etc/hosts

# install time synchronization server
# apt update
# apt-get install ntp -y
# apt-get install ntpdate -y
# ntpdate -u ntp.ubuntu.com
# echo "...done..."

# Forwarding IPv4 and letting iptables see bridged traffic:
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

# Restart systemd-resolved service
service systemd-resolved restart

# Disable swap
sed -i '/swap/d' /etc/fstab
swapoff -a
