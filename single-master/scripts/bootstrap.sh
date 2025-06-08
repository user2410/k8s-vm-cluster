#!/bin/bash

set -eux

HOME_CONFIG=/home/vagrant/k8sconfigs

# Update hosts file

sudo echo "# Kubernetes Cluster Hosts" >> /etc/hosts
sudo cat $HOME_CONFIG/hosts_addition >> /etc/hosts

# install time synchronization server
# sudo apt update
# sudo apt-get install ntp -y
# sudo apt-get install ntpdate -y
# sudo ntpdate -u ntp.ubuntu.com
# echo "...done..."

# Forwarding IPv4 and letting iptables see bridged traffic:
## Add kernel modules
sudo cat << EOF >> /etc/modules-load.d/k8s.conf
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
br_netfilter
nf_conntrack
overlay
EOF
sudo cat /etc/modules-load.d/k8s.conf >> /etc/modules
sudo modprobe overlay
sudo modprobe br_netfilter
sudo systemctl restart systemd-modules-load.service

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
sudo sysctl --system
echo "...done..."

# Point to Google's DNS server
sudo sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf
sudo service systemd-resolved restart

# Disable swap
sudo sed -i '/swap/d' /etc/fstab
sudo swapoff -a
echo "...done..."
