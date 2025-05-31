# VMs configuration file

## machines.txt

- This file contains the configuration of the virtual machines used in the single-master setup.
- The first line shows details about the master node. This line is structured as follows:

```plain
<master_node_ip> <master_node_hostname> <master_node_fqdn> <pod_cidr> <service_cidr>
```

  where:
    - `<master_node_ip>`: The IP address of the master node.
    - `<master_node_hostname>`: The hostname of the master node.
    - `<master_node_fqdn>`: The fully qualified domain name (FQDN) of the master node.
    - `<pod_cidr>`: The CIDR block for the pod network.
    - `<service_cidr>`: The CIDR block for the service network.

- The subsequent lines provide information about the worker nodes. The structure of each line is as follows:

```plain
<worker_node_ip> <worker_node_hostname> <worker_node_fqdn> <pod_subnet>
```

  where:
    - `<worker_node_ip>`: The IP address of the worker node.
    - `<worker_node_hostname>`: The hostname of the worker node.
    - `<worker_node_fqdn>`: The fully qualified domain name (FQDN) of the worker node.
    - `<pod_subnet>`: The subnet for the pods on this worker node.
