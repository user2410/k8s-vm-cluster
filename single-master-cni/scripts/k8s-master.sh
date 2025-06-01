#!/bin/bash

set -eux

K8S_VER=v1.33.1
ARCH=$(dpkg --print-architecture)
HOME_CONFIG=/home/vagrant/k8sconfigs
CERT_DIR=$HOME_CONFIG/certs
CONFIG_DIR=$HOME_CONFIG/configs
KUBECONFIG_DIR=$HOME_CONFIG/kubeconfigs
UNIT_DIR=$HOME_CONFIG/units


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

## Create Kubernetes configuration directory
mkdir -p /etc/kubernetes/config /var/lib/kubernetes/pki /var/lib/kubernetes/

## Configure Kubernetes API Server
cp $CERT_DIR/{ca.crt,ca.key,kube-api-server.key,kube-api-server.crt,service-accounts.key,service-accounts.crt,etcd.crt,etcd.key} \
  /var/lib/kubernetes/

### Generate a random encryption key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

sed "s|{ENCRYPTION_KEY}|$ENCRYPTION_KEY|g" $CONFIG_DIR/encryption-config.yaml > /var/lib/kubernetes/encryption-config.yaml

cp $UNIT_DIR/kube-apiserver.service \
  /etc/systemd/system/kube-apiserver.service

## Configure Kubernetes Controller Manager

### Move `kube-controller-manager` kubeconfig into place:
cp $KUBECONFIG_DIR/kube-controller-manager.kubeconfig /var/lib/kubernetes/

### Create `kube-controller-manager.service` systemd unit file:
cp $UNIT_DIR/kube-controller-manager.service /etc/systemd/system/


## Configure Kubernetes Scheduler

### Move `kube-scheduler` kubeconfig into place:
cp $KUBECONFIG_DIR/kube-scheduler.kubeconfig /var/lib/kubernetes/

### Create `kube-scheduler.yaml` configuration file:
cp $CONFIG_DIR/kube-scheduler.yaml /etc/kubernetes/config/

### Create `kube-scheduler.service` systemd unit file:
cp $UNIT_DIR/kube-scheduler.service /etc/systemd/system/

## Start Controller Services

systemctl daemon-reload

systemctl enable kube-apiserver \
  kube-controller-manager kube-scheduler

systemctl start kube-apiserver \
  kube-controller-manager kube-scheduler

### > Allow up to 10 seconds for Kubernetes API Server to fully initialize.
sleep 10

## Verify
for i in kube-apiserver kube-controller-manager kube-scheduler; do
  if systemctl is-active --quiet $i; then
    echo "$i is active"
  else
    echo "$i is not active"
    exit 1
  fi
done

### At this point Kubernetes control plane components should be up and running. 
### Verify this using `kubectl` command line tool:
kubectl cluster-info \
  --kubeconfig $KUBECONFIG_DIR/admin.kubeconfig


## RBAC for Kubelet Authorization
## Configure RBAC permissions to allow Kubernetes API Server to access Kubelet API on each worker node. 

### Access to Kubelet API is required for retrieving metrics, logs, and executing commands in pods.

### Set kubelet `--authorization-mode` flag to `Webhook`. 
### Webhook mode uses [SubjectAccessReview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#checking-api-access) API to determine authorization.
### The commands in this section will affect the entire cluster and only need to be run on `server` machine.


### Create `system:kube-apiserver-to-kubelet` [ClusterRole](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole) with permissions to access Kubelet API and perform most common tasks associated with managing pods:
kubectl apply -f $CONFIG_DIR/kube-apiserver-to-kubelet.yaml \
  --kubeconfig $KUBECONFIG_DIR/admin.kubeconfig
