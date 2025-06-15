# Kubernetes Cluster with Vagrant

⚡ **Spin up a basic Kubernetes cluster within minutes using Vagrant and VirtualBox.**

## 🚀 Project Goal

This project aims to **automate the setup of a local Kubernetes cluster** using Vagrant for VM provisioning and VirtualBox for virtualization. It is designed to be a minimal, reproducible environment for learning, testing, or developing Kubernetes-native applications without needing cloud infrastructure.

> ✅ **Current milestone**: A production-grade Kubernetes cluster with secure networking  
> (1 master node + 2 worker nodes)

---

## 🧱 Cluster Topology

Depending on VirtualBox host-only interface settings of VirtualBox, the cluster will be set up differently on each machine. For example, if the host-only interface is set to `172.16.10.0/24`, the cluster will be configured as follows:

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
- [go-task](https://taskfile.dev/) for running automated tasks
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
- TLS bootstrap is enabled for secure node registration
- Production-grade CNI (Calico or Flannel) for pod networking

---

## 📂 Directory Structure

```
vagrant-kubernetes-EZ/
├── single-master/                # Basic cluster with bridge CNI
│   ├── certs/                    # Certificate files
│   ├── configs/                  # Kubernetes configuration files
│   ├── kubeconfigs/              # Kubeconfig files
│   ├── notes/                    # Documentation notes
│   ├── scripts/                  # Setup scripts
│   ├── tasks/                    # Task definitions
│   ├── units/                    # Systemd unit files
│   └── Vagrantfile               # VM configuration
├── single-master-cni/            # Production-grade cluster with CNI
│   ├── certs/                    # TLS certificates
│   ├── configs/                  # Kubernetes configurations
│   ├── kubeconfigs/              # Kubeconfig files
│   ├── notes/                    # Documentation on specific features
│   ├── scripts/                  # Setup scripts
│   ├── tasks/                    # Task definitions
│   ├── units/                    # Systemd unit files
│   └── Vagrantfile               # VM configuration
└── README.md
```

---

## 🏁 Getting Started

### Prerequisites

1. **Install dependencies**

   - Install VirtualBox: [VirtualBox Downloads](https://www.virtualbox.org/wiki/Downloads)
   - Install Vagrant: [Vagrant Downloads](https://www.vagrantup.com/downloads)
   - Install go-task: [Task Installation](https://taskfile.dev/installation/)

2. **Set up VirtualBox host-only network**

   ```bash
   # Create a host-only network in VirtualBox
   VBoxManage hostonlyif create
   
   # Configure the network (example for 172.16.10.0/24)
   VBoxManage hostonlyif ipconfig vboxnet0 --ip 172.16.10.1 --netmask 255.255.255.0
   ```

### Deploying the Cluster

1. **Clone the repository**

   ```bash
   git clone https://github.com/user2410/vagrant-kubernetes-EZ.git
   cd vagrant-kubernetes-EZ/single-master-cni
   ```

2. **Start the cluster**

   ```bash
   # Build the entire cluster
   task build
   ```

   This command will:
   - Generate certificates
   - Create kubeconfig files
   - Provision VMs
   - Install and configure Kubernetes components
   - Set up the CNI networking

3. **Verify the cluster**

   ```bash
   # SSH into the master node
   vagrant ssh master
   
   # Check node status
   kubectl get nodes
   ```

   You should see all 3 nodes in `Ready` state.

---

## 📌 Milestones

### ✅ Milestone 1 – Minimal 3-node cluster

- [x] Vagrant spins up VMs with static IPs
- [x] Initializes cluster on master
- [x] Worker nodes join the cluster
- [x] Core system pods are running
- [x] The cluster is using the **reference CNI plugins** - suitable for testing or minimal environments.
- [x] Deployment of `nginx` example app

### ✅ Milestone 2 – Production-grade Networking (current)

- [x] Generated certificates for etcd with TLS integration
- [x] Enabled TLS bootstrap for secure node registration
- [x] Implemented certificate rotation for worker nodes
- [x] Installed and configured production-grade CNI (Calico and Flannel)
- [x] Enabled inter-pod networking and `kubectl exec`
- [x] Allow access to services via NodePort

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
- For certificate-related issues, check the notes in `single-master-cni/notes/` directory.

---

## 📖 License

This project is open-sourced under the MIT License.

---

## 🙌 Credits

Built and maintained by [user2410](https://github.com/user24).
Inspired by the goal of making Kubernetes easy to learn and experiment with locally.