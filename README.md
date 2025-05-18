# Kubernetes Cluster with Vagrant

⚡ **Spin up a basic Kubernetes cluster within minutes using Vagrant and VirtualBox.**

## 🚀 Project Goal

This project aims to **automate the setup of a local Kubernetes cluster*- using Vagrant for VM provisioning and VirtualBox for virtualization. It is designed to be a minimal, reproducible environment for learning, testing, or developing Kubernetes-native applications without needing cloud infrastructure.

> ✅ **Current milestone**: A working 3-node Kubernetes cluster  
> (1 master node + 2 worker nodes)

---

## 🧱 Cluster Topology

| Node      | Role   | IP Address     | Vagrant Hostname |
|-----------|--------|----------------|------------------|
| master    | Master | `172.16.10.2`  | `master`         |
| worker1   | Worker | `172.16.10.3`  | `worker1`        |
| worker2   | Worker | `172.16.10.4`  | `worker2`        |

All nodes are connected via a private VirtualBox network (`vboxnet0`).

---

## 📦 Requirements

- [Vagrant](https://www.vagrantup.com/) >= 2.2
- [VirtualBox](https://www.virtualbox.org/) >= 6.1
- UNIX-like OS (Linux/macOS/WSL2)

---

## 🔧 How It Works

- Vagrant spins up 3 VMs: 1 master and 2 workers.
- Each VM is configured with:
  - Static IP on a private network
  - Docker
  - Kubernetes (kubeadm, kubelet, kubectl)
- The master node is initialized with `kubeadm init`
- Worker nodes join using the token provided by the master

---

## 📂 Directory Structure

```

k8s-vagrant-cluster/
├── Vagrantfile
├── scripts/
│   ├── master.sh        # Setup script for master node
│   └── worker.sh        # Setup script for worker nodes
├── kubeconfigs/         # (Optional) Stores kubeconfig for local `kubectl`
└── README.md

````

---

## 🏁 Getting Started

1. **Clone the repository**

```bash
git clone https://github.com/user2410/k8s-vagrant-cluster.git
cd k8s-vagrant-cluster
```

2. **Start the cluster**

```bash
task build
```

3. **Verify from the master node**

```bash
vagrant ssh master
kubectl get nodes
```

You should see all 3 nodes in `Ready` state.

---

## 📌 Milestones

### ✅ Milestone 1 – Minimal 3-node cluster (current)

- [x] Vagrant spins up VMs with static IPs
- [x] Initializes cluster on master
- [x] Worker nodes join the cluster
- [x] Core system pods are running

### 🔜 Milestone 2 – Network Add-on & NodePort

- [ ] Install and configure CNI (Flannel or Calico)
- [ ] Enable inter-pod networking and `kubectl exec`
- [ ] Allow access to services via NodePort

### 🔮 Future Plans

- Support dynamic IPs
- Add more nodes or HA setup
- Automate provisioning with Ansible
- Integrate MetalLB or Ingress Controller

---

## 🐛 Troubleshooting

- Make sure `172.16.10.0/24` does not conflict with your host's existing network.
- If you see connection refused errors from workers to master, ensure:

  - API server is listening on the correct interface/IP
  - No firewalls block port `6443`
  - `--bind-address` in `kube-apiserver` matches internal network IP

---

## 📖 License

This project is open-sourced under the MIT License.

---

## 🙌 Credits

Built and maintained by [user2410](https://github.com/user24).
Inspired by the goal of making Kubernetes easy to learn and experiment with locally.

Let me know if you'd like me to tailor this to your exact repo name or include example IP ranges from your `Vagrantfile`.
