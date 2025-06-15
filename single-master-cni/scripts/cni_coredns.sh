#!/bin/bash

set -eux

# This script installs the specified CNI plugin and CoreDNS.

HOME_CONFIG=/home/vagrant/k8sconfigs
CERT_DIR=$HOME_CONFIG/certs
CONFIG_DIR=$HOME_CONFIG/configs
KUBECONFIG_DIR=$HOME_CONFIG/kubeconfigs
UNIT_DIR=$HOME_CONFIG/units

# Arguments:
# $1 - CNI plugin name (Flannel, Weave, Cilium, Calico)
# $2 - Pod CIDR
# $3 - Service CIDR
CNI_PLUGIN=$1
POD_CIDR=$2
SERVICE_CIDR=$3
if [ -z "$CNI_PLUGIN" ]; then
  CNI_PLUGIN="Flannel"
fi

if [ -z "$POD_CIDR" ]; then
  POD_CIDR="10.244.0.0/16"
fi

if [ -z "$SERVICE_CIDR" ]; then
  SERVICE_CIDR="10.252.0.0/16"
fi

ARCH=$(dpkg --print-architecture)

# Define versions for CNI plugins
FLANNEL_VERSION=v0.26.7
WEAVE_VERSION=v2.8.1
CILIUM_VERSION=v1.14.5
CALICO_VERSION=v3.30.0

echo "$CNI_PLUGIN Networking plugin selected"

if [ "$CNI_PLUGIN" == "Flannel" ]; then

  echo "Installing Flannel CNI plugin $FLANNEL_VERSION"

  # kubectl apply -f https://github.com/flannel-io/flannel/releases/download/$FLANNEL_VERSION/kube-flannel.yml
  wget -P $CONFIG_DIR/ https://github.com/flannel-io/flannel/releases/download/$FLANNEL_VERSION/kube-flannel.yml
  sed -i.bak "s|\"Network\": \"[^\"]*\"|\"Network\": \"$POD_CIDR\"|" "$CONFIG_DIR/kube-flannel.yml"
  kubectl apply -f $CONFIG_DIR/kube-flannel.yml --kubeconfig $KUBECONFIG_DIR/admin.kubeconfig

elif [ "$CNI_PLUGIN" == "Calico" ]; then

  echo "Installing Calico CNI plugin"

  echo "Installing the Tigera operator and custom resource definitions
  ! You skip the Operator if you want a manual, self-managed installation of Calico."
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/operator-crds.yaml --kubeconfig $KUBECONFIG_DIR/admin.kubeconfig
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml --kubeconfig $KUBECONFIG_DIR/admin.kubeconfig
  
  echo "Installing Calico CNI plugin version: $CALICO_VERSION"
  wget -P $CONFIG_DIR/ https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml
  ## Modify the custom resources to set the pod CIDR
  sed -i "s|^\([[:space:]]*cidr:\)[[:space:]]*.*$|\1 $POD_CIDR|" $CONFIG_DIR/custom-resources.yaml
  kubectl create -f $CONFIG_DIR/custom-resources.yaml --kubeconfig $KUBECONFIG_DIR/admin.kubeconfig

# Weave is deprecated in favor of Cilium and Calico, so it's commented out.
# elif [ "$CNI_PLUGIN" == "Weave" ]; then

#   echo "Installing Weave CNI plugin $WEAVE_VERSION"

#   kubectl apply -f https://github.com/weaveworks/weave/releases/download/$WEAVE_VERSION/weave-daemonset-k8s.yaml

# Cilium does not allow preconfiguring the pod CIDR
# elif [ "$CNI_PLUGIN" == "Cilium" ]; then

#   echo "Installing Cilium networking plugin"

#   CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
#   echo "Installing Cilium CLI version: $CILIUM_CLI_VERSION"
#   wget -q --show-progress --fail -O cilium-linux-${ARCH}.tar.gz "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz"
#   wget -q --show-progress --fail -O cilium-linux-${ARCH}.tar.gz.sha256sum "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz.sha256sum"

#   echo "Verifying Cilium CLI tarball"
#   sha256sum --check cilium-linux-${ARCH}.tar.gz.sha256sum
#   tar xzvfC cilium-linux-${ARCH}.tar.gz /usr/local/bin
#   rm cilium-linux-${ARCH}.tar.gz{,.sha256sum}

#   echo "Installing Cilium CNI plugin version: $CILIUM_VERSION"
#   cilium install --version $CILIUM_VERSION

else
  echo "Unknown pod network plugin specified in config file"
fi


# Configure CoreDNS

## Install Helm
HELM_VER=3.18.2
wget -q --show-progress --https-only --timestamping -P /tmp/ https://get.helm.sh/helm-v$HELM_VER-linux-$ARCH.tar.gz
tar -xzf /tmp/helm-v$HELM_VER-linux-$ARCH.tar.gz -C /tmp/
mv /tmp/linux-$ARCH/helm /usr/local/bin/helm
chmod +x /usr/local/bin/helm
rm -rf /tmp/helm-v$HELM_VER-linux-$ARCH.tar.gz /tmp/linux-$ARCH

## Install CoreDNS using Helm
echo "Installing CoreDNS using Helm"
helm repo add coredns https://coredns.github.io/helm
helm install coredns coredns/coredns \
  --namespace kube-system \
  --kubeconfig $KUBECONFIG_DIR/admin.kubeconfig
