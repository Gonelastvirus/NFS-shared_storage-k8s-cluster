#!/bin/bash

# Define global variables
nfs_server=""
nfs_path=""
pvc_name=""
storage_class_name=""
storage_size=""

# Function to check if NFS CSI driver is installed
is_csi_driver_installed() {
    local controller_pods=$(kubectl -n kube-system get pod -l app=csi-nfs-controller -o jsonpath='{.items[*].metadata.name}')
    local node_pods=$(kubectl -n kube-system get pod -l app=csi-nfs-node -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$controller_pods" || -z "$node_pods" ]]; then
        return 1
    else
        return 0
    fi
}

# Function to install NFS CSI driver v4.7.0 using remote install method
install_csi_driver() {
    curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.7.0/deploy/install-driver.sh | bash -s v4.7.0 --
}

# Function to check pods status
check_pods_status() {
    echo "Checking pods status..."
    local controller_pods_ready=$(kubectl -n kube-system get pod -l app=csi-nfs-controller -o 'jsonpath={.items[*].status.containerStatuses[*].ready}' | grep -o true | wc -l)
    local node_pods_ready=$(kubectl -n kube-system get pod -l app=csi-nfs-node -o 'jsonpath={.items[*].status.containerStatuses[*].ready}' | grep -o true | wc -l)
    local total_controller_pods=$(kubectl -n kube-system get pod -l app=csi-nfs-controller -o 'jsonpath={.items[*].metadata.name}' | wc -w)
    local total_node_pods=$(kubectl -n kube-system get pod -l app=csi-nfs-node -o 'jsonpath={.items[*].metadata.name}' | wc -w)

    echo "CSI NFS Controller Pods Ready: $controller_pods_ready / $total_controller_pods"
    echo "CSI NFS Node Pods Ready: $node_pods_ready / $total_node_pods"

    if [[ "$controller_pods_ready" -eq "$total_controller_pods" && "$node_pods_ready" -eq "$total_node_pods" ]]; then
        echo "All pods are running. Proceeding to create StorageClass and PVC..."
    else
        echo "Not all pods are running. Waiting 10 seconds before checking again..."
        sleep 10
        check_pods_status
    fi
}

# Function to prompt user input for NFS details, StorageClass, and PVC
prompt_user_input() {
    read -p "Enter NFS Server IP or Hostname: " nfs_server
    read -p "Enter NFS Exported Path: " nfs_path
    read -p "Enter PersistentVolumeClaim (PVC) Name: " pvc_name
    read -p "Enter StorageClass Name (e.g., nfs-csi): " storage_class_name
    read -p "Enter Storage Size (e.g., 10Gi): " storage_size
}

# Function to create StorageClass and PVC
create_storage_class_and_pvc() {
    # Create StorageClass YAML
    cat <<EOF > nfs-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $storage_class_name
provisioner: nfs.csi.k8s.io
parameters:
  server: $nfs_server
  share: $nfs_path
reclaimPolicy: Delete  # Adjust as needed
volumeBindingMode: Immediate
mountOptions:
 - hard
 - nfsvers=4.1
EOF

    # Apply StorageClass
    kubectl apply -f nfs-storage-class.yaml

    # Create PVC YAML
    cat <<EOF > $pvc_name-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $pvc_name
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: $storage_class_name
  resources:
    requests:
      storage: $storage_size
EOF

    # Apply PVC
    kubectl apply -f $pvc_name-pvc.yaml

    echo "StorageClass and PVC created successfully."
}

# Check if CSI driver is already installed
if is_csi_driver_installed; then
    echo "CSI driver is already installed. Skipping installation."
else
    echo "CSI driver not found. Installing..."
    install_csi_driver
fi

# Call function to prompt user input
prompt_user_input

# Call function to check pods status
check_pods_status

# Call function to create StorageClass and PVC after pods are running
create_storage_class_and_pvc

# Add any additional steps here after StorageClass and PVC creation
echo "Storage setup complete. Proceeding with additional steps."
