# Adding and Reloading Worker Nodes in the Cluster

## Overview

This document outlines the process of adding new worker nodes to an existing Kubernetes cluster and properly reloading VMs when necessary.

## Adding a New Worker Node

When adding a new worker node to the cluster:

1. Provision the VM with Vagrant
2. Install prerequisites (containerd, kubelet, kubeadm)
3. Configure TLS bootstrap
4. Join the node to the cluster

## VM Reload Process

When reloading a VM that will be added as a worker node, follow these steps to ensure proper integration:

### 1. Prepare the VM for Reload

```bash
# Gracefully drain the node (if it was previously part of the cluster)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Delete the node from the cluster
kubectl delete node <node-name>
```

### 2. Reload the VM

```bash
# Halt and reload the VM
vagrant halt <vm-name>
vagrant up <vm-name>
```

### 3. Clean Up Old Certificates

On the worker node after reload:

```bash
# Remove old certificates and configuration
sudo rm -rf /var/lib/kubelet/pki
sudo rm -f /etc/kubernetes/kubelet.conf
```

### 4. Rejoin the Cluster

```bash
# Get a new bootstrap token from the master (if needed)
# On master:
kubeadm token create --print-join-command

# On worker:
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

### 5. Verify Node Status

```bash
# Check node status
kubectl get nodes
```

## Common Issues and Solutions

### Node Fails to Join with Certificate Errors

If a node fails to join with certificate errors:

1. Ensure all old certificates are removed from the worker node
2. Verify the bootstrap token is valid and not expired
3. Check that the node has network connectivity to the master
4. Verify that CSR auto-approval is configured correctly

### Node Joins but Remains in NotReady State

If a node joins but remains in NotReady state:

1. Check kubelet status: `systemctl status kubelet`
2. Examine kubelet logs: `journalctl -u kubelet`
3. Verify CNI is properly configured
4. Check node network connectivity

## References

- [Kubernetes Node Management](https://kubernetes.io/docs/concepts/architecture/nodes/)
- [kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/)
- [Node Maintenance](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)