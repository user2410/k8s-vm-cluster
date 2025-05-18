#!/bin/bash

set -eux

K8S_VER=v1.33.1
ARCH=$(dpkg --print-architecture)
CONFIG_ORIGINAL_DIR=/vagrant/configs
KUBECONFIG_ORIGINAL_DIR=/vagrant/kubeconfigs
UNIT_ORIGINAL_DIR=/vagrant/units

# Install Kubernetes components

cat <<EOF > /tmp/downloads.txt
https://dl.k8s.io/$K8S_VER/bin/linux/$ARCH/kubectl
https://dl.k8s.io/$K8S_VER/bin/linux/$ARCH/kube-apiserver
https://dl.k8s.io/$K8S_VER/bin/linux/$ARCH/kube-controller-manager
https://dl.k8s.io/$K8S_VER/bin/linux/$ARCH/kube-scheduler
EOF

wget -q --show-progress \
  --https-only \
  --timestamping \
  -P /usr/local/bin/ \
  -i /tmp/downloads.txt

chmod +x /usr/local/bin/{kubectl,kube-apiserver,kube-controller-manager,kube-scheduler}

# Configure Kubernetes components

## Create the Kubernetes configuration directory
mkdir -p /etc/kubernetes/config 

## Configure the Kubernetes API Server
mkdir -p /var/lib/kubernetes/

cp /vagrant/certs/{ca.crt,ca.key,kube-api-server.key,kube-api-server.crt,service-accounts.key,service-accounts.crt} \
  /var/lib/kubernetes/

### Generate a random encryption key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

sed -i "s|\${ENCRYPTION_KEY}|$ENCRYPTION_KEY|g" $CONFIG_ORIGINAL_DIR/encryption-config.yaml > /var/lib/kubernetes/encryption-config.yaml

cp $UNIT_ORIGINAL_DIR/kube-apiserver.service \
  /etc/systemd/system/kube-apiserver.service

## Configure the Kubernetes Controller Manager

### Move the `kube-controller-manager` kubeconfig into place:
cp $KUBECONFIG_ORIGINAL_DIR/kube-controller-manager.kubeconfig /var/lib/kubernetes/

### Create the `kube-controller-manager.service` systemd unit file:
cp $UNIT_ORIGINAL_DIR/kube-controller-manager.service /etc/systemd/system/


## Configure the Kubernetes Scheduler

### Move the `kube-scheduler` kubeconfig into place:
cp $KUBECONFIG_ORIGINAL_DIR/kube-scheduler.kubeconfig /var/lib/kubernetes/

### Create the `kube-scheduler.yaml` configuration file:
cp $CONFIG_ORIGINAL_DIR/kube-scheduler.yaml /etc/kubernetes/config/

### Create the `kube-scheduler.service` systemd unit file:
cp $UNIT_ORIGINAL_DIR/kube-scheduler.service /etc/systemd/system/

## Start the Controller Services

systemctl daemon-reload

systemctl enable kube-apiserver \
  kube-controller-manager kube-scheduler

systemctl start kube-apiserver \
  kube-controller-manager kube-scheduler

### > Allow up to 10 seconds for the Kubernetes API Server to fully initialize.
sleep 10

## Verification

### You can check if any of the control plane components are active using the `systemctl` command. For example, to check if the `kube-apiserver` fully initialized, and active, run the following command:
for i in kube-apiserver kube-controller-manager kube-scheduler; do
  if systemctl is-active --quiet $i; then
    echo "$i is active"
  else
    echo "$i is not active"
    journalctl -u $i -n 50 | head -n 50
    echo "================================"
  fi
done

### At this point the Kubernetes control plane components should be up and running. 
### Verify this using the `kubectl` command line tool:
kubectl cluster-info \
  --kubeconfig $KUBECONFIG_ORIGINAL_DIR/admin.kubeconfig


## RBAC for Kubelet Authorization
## Configure RBAC permissions to allow the Kubernetes API Server to access the Kubelet API on each worker node. 

### Access to the Kubelet API is required for retrieving metrics, logs, and executing commands in pods.

### Set the Kubelet `--authorization-mode` flag to `Webhook`. 
### Webhook mode uses the [SubjectAccessReview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#checking-api-access) API to determine authorization.
### The commands in this section will affect the entire cluster and only need to be run on the `server` machine.


### Create the `system:kube-apiserver-to-kubelet` [ClusterRole](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole) with permissions to access the Kubelet API and perform most common tasks associated with managing pods:
kubectl apply -f $CONFIG_ORIGINAL_DIR/kube-apiserver-to-kubelet.yaml \
  --kubeconfig $KUBECONFIG_ORIGINAL_DIR/admin.kubeconfig
