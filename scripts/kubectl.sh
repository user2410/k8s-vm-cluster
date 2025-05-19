#!/bin/bash

set -eux

K8S_CLUSTER_NAME=k8s-cluster
CERT_ORIGINAL_DIR=/vagrant/certs

kubectl config set-cluster $K8S_CLUSTER_NAME \
    --certificate-authority=$CERT_ORIGINAL_DIR/ca.crt \
    --embed-certs=true \
    --server=https://master.kubernetes.local:6443

kubectl config set-credentials admin \
  --client-certificate=$CERT_ORIGINAL_DIR/admin.crt \
  --client-key=$CERT_ORIGINAL_DIR/admin.key

kubectl config set-context $K8S_CLUSTER_NAME \
  --cluster=$K8S_CLUSTER_NAME \
  --user=admin

kubectl config use-context $K8S_CLUSTER_NAME
