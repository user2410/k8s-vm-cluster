# Certificate Rotation and CSR Approval for Worker Nodes

## Overview

This document explains the process of approving Certificate Signing Requests (CSRs) for worker nodes and implementing certificate rotation in a Kubernetes cluster.

## TLS Bootstrap Process

When a new worker node joins the cluster using TLS bootstrap:

1. The kubelet uses a bootstrap token to authenticate to the Kubernetes API server
2. It generates a key pair and submits a CSR to the API server
3. The CSR must be approved before the kubelet can establish a secure connection

## Approving CSRs

### Manual Approval

To manually approve pending CSRs:

```bash
# List pending CSRs
kubectl get csr

# Approve a specific CSR
kubectl certificate approve <csr-name>
```

### Automatic Approval

We've implemented automatic approval using RBAC configurations:

1. `auto-approve-csrs-for-group.yaml` - Approves node bootstrapping CSRs
2. `auto-approve-kubelet-serving-csrs.yaml` - Approves kubelet serving certificate CSRs
3. `auto-approve-renewals-for-nodes.yaml` - Approves certificate renewal CSRs

These configurations are applied during cluster setup to streamline node joining.

## Certificate Rotation

Kubernetes supports automatic certificate rotation for kubelet client and server certificates:

1. The kubelet will automatically request new certificates when they reach 70-80% of their validity period
2. With our auto-approval configurations, these rotation requests are automatically approved
3. The kubelet seamlessly transitions to the new certificates

### Configuration

Certificate rotation is enabled in the kubelet configuration with:

```yaml
rotateCertificates: true
serverTLSBootstrap: true
```

## Troubleshooting

If a node shows certificate-related issues:

1. Check pending CSRs: `kubectl get csr`
2. Verify the auto-approval configurations are applied
3. Check kubelet logs: `journalctl -u kubelet`
4. Ensure the node has the correct bootstrap token if it needs to rejoin

## References

- [Kubernetes TLS Bootstrapping](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-tls-bootstrapping/)
- [Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)
- [Kubelet Configuration](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/)