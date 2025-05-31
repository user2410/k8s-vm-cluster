#/bin/bash

set -eux

CNI_PLUGIN=

ARCH=$(dpkg --print-architecture)

FLANNEL_VERSION=v0.26.7
WEAVE_VERSION=v2.8.1
CILIUM_VERSION=v1.14.5
CALICO_VERSION=v3.30.0

echo "$CNI_PLUGIN Networking plugin selected"

if [ "$CNI_PLUGIN" == "Flannel" ]; then
    echo "Installing Flannel CNI plugin $FLANNEL_VERSION"
    kubectl apply -f https://github.com/flannel-io/flannel/releases/download/$FLANNEL_VERSION/kube-flannel.yml
elif [ "$CNI_PLUGIN" == "Weave" ]; then
    echo "Installing Weave CNI plugin $WEAVE_VERSION"
    kubectl apply -f https://github.com/weaveworks/weave/releases/download/$WEAVE_VERSION/weave-daemonset-k8s.yaml
elif [ "$CNI_PLUGIN" == "Cilium" ]; then
    echo "Installing Cilium networking plugin"

    echo "Installing Cilium CLI version: $CILIUM_CLI_VERSION"
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${ARCH}.tar.gz{,.sha256sum}

    echo "Installing Cilium CNI plugin version: $CILIUM_VERSION"
    cilium install --version $CILIUM_VERSION
elif [ "$CNI_PLUGIN" == "Calico" ]; then
    echo "Installing Calico CNI plugin"

    echo "Installing the Tigera operator and custom resource definitions
    ! You skip the Operator if you want a manual, self-managed installation of Calico."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/operator-crds.yaml
    
    echo "Installing Calico CNI plugin version: $CALICO_VERSION"
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml
else
    echo "Unknown pod network plugin specified in config file"
fi
