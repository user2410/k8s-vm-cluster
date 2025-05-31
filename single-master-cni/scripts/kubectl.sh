#!/bin/bash

set -eux

# Arguments:
# $1 - Kubernetes master FQDN
MASTER_FQDN=master.kubernetes.local

CLUSTER_NAME=k8s-cluster
HOME_CONFIG=/home/vagrant/k8sconfigs
CERT_DIR=$HOME_CONFIG/certs

kubectl config set-cluster $CLUSTER_NAME \
    --certificate-authority=$CERT_DIR/ca.crt \
    --embed-certs=true \
    --server=https://$MASTER_FQDN:6443

kubectl config set-credentials admin \
  --client-certificate=$CERT_DIR/admin.crt \
  --client-key=$CERT_DIR/admin.key

kubectl config set-context $CLUSTER_NAME \
  --cluster=$CLUSTER_NAME \
  --user=admin

kubectl config use-context $CLUSTER_NAME
