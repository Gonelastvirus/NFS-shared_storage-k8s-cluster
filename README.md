# NFS-shared_storage-k8s-cluster
When you run applications on a Kubernetes cluster, they typically need to store data permanently, not just temporarily in memory. Imagine you have a web server that needs to store user-uploaded files or a database that stores critical information. In Kubernetes, these applications can't rely on the local disk of the nodes (like the Mac Minis) because those disks are meant for temporary use.

Instead, Kubernetes uses something called Persistent Volumes (PVs) to provide storage that persists even if your application moves to a different node or restarts. Think of it like renting a storage unit: your application asks Kubernetes for a "storage unit" (PV) where it can safely store data.

For example, if you have a WordPress site running on Kubernetes, it needs to store blog posts and images. You'd define a Persistent Volume Claim (PVC) in Kubernetes, which is like reserving a specific size storage unit (say, 10GB). Kubernetes then ensures this storage is available to your WordPress application wherever it runs in the cluster.

So, even if your WordPress container moves from one Mac Mini to another, it still connects to the same storage unit (PV) and can access all the saved blog posts and images without losing any data. This makes Kubernetes very flexible for managing applications that need to store data reliably.

# The Issues with HostPath Storage

![0_9kIL-QAzNQvER6O5](https://github.com/Gonelastvirus/NFS-shared_storage-k8s-cluster/assets/67478827/deb1093b-bb25-4ac7-b7cb-86f20c7a605a)
![0_jppxm88aKKQUQXaE](https://github.com/Gonelastvirus/NFS-shared_storage-k8s-cluster/assets/67478827/dab20d0f-2c9a-41ea-bcbc-9ad2eb166ac2)

When you start using multiple nodes in a Kubernetes cluster, storing data becomes tricky. Here's why:

<b>1. Single Node Setup:</b>
    If you have a single-node Kubernetes setup, storing data is easy. You can use a "host path" volume, which means the data is stored on the same machine as the application. So, if your app restarts, it always finds the data because everything is on the same node.

<b>2. Multi-Node Setup:</b>
    Things get complicated when you add more nodes. For example, if you have a two-node cluster:<br>
      <b>  Issue 1: Volume Availability</b>
        Imagine you have an app running on node 1 with its data stored on node 1. If the app gets moved to node 2 (maybe node 1 is too busy), the app on node 2 can't find its data because the data is still on node 1.
            Example: You have a web app running on node 1 that stores images. If Kubernetes moves this app to node 2 due to high load on node 1, the app on node 2 won't find the images since they are still stored on node 1.
     <br> <b>  Issue 2: Scaling Problems</b>
        If you want to run multiple instances of the same app (one on each node), you face two problems:
            Unavailable Volume: The new instance on node 2 still can't access the data stored on node 1.
            Read-Write Restrictions: Even if the data is accessible from both nodes, only one instance can write to the volume at a time.
            Example: You scale your web app to run on both nodes. The app on node 2 can't access the images stored on node 1. Even if both instances could access the images, only one of them can upload new images because of the read-write restriction.

In short, with multiple nodes, managing storage becomes challenging because of issues with data availability and write permissions.

# Adding NFS to One of Your Nodes (not recommended)

![0_exzQng3B8_iRzo6K](https://github.com/Gonelastvirus/NFS-shared_storage-k8s-cluster/assets/67478827/e219791f-ee82-446f-af8f-c050c88d8789)

<b>if the node with NFS went down, the other node would obviously not be able to mount the volumes it needs.</b>

![0_caZujI0tg6Nd_ix6](https://github.com/Gonelastvirus/NFS-shared_storage-k8s-cluster/assets/67478827/11c0fcf3-b976-4515-ba85-578e700084cf)


# NFS To The Rescue!

Luckily there’s a pretty easy way to solve all of this. It’s called the Kubernetes NFS provisioner (or NFS container storage interface). NFS servers have been around for forever and have provided a simple way for multiple workloads to connect to one disk. It even allows both workloads to read and write simultaneously. The NFS CSI allows a multi-node Kubernetes cluster to create and mount volumes that are backed by NFS. Installing and configuring the CSI is a one-time thing and after that, it’s completely transparent to the user of the cluster.

# Below is Example output 

<b>Look again at the PersistentVolume:</b>

    kubectl get pv task-pv-volume

<b>Now the output shows a STATUS of Bound.</b>

    NAME             CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS    CLAIM                   STORAGECLASS   REASON    AGE
    task-pv-volume   10Gi       RWO           Retain          Bound     default/task-pv-claim   manual                   2m

<b>Look at the PersistentVolumeClaim:</b>

    kubectl get pvc task-pv-claim

<b>The output shows that the PersistentVolumeClaim is bound to your PersistentVolume.</b>

    NAME            STATUS    VOLUME           CAPACITY   ACCESSMODES   STORAGECLASS   AGE
    task-pv-claim   Bound     task-pv-volume   10Gi       RWO           manual         30s


# Example of creating pod and using persistent volume  you just created running script
In the NFS shared directory, create an index.html file:

    # This again assumes that your Node uses "sudo" to run commands
    # as the superuser
    sudo sh -c "echo 'Hello from Kubernetes storage' > /mnt/data/index.html"
    
Create a pod

    apiVersion: v1
    kind: Pod
    metadata:
      name: task-pv-pod
    spec:
      volumes:
        - name: task-pv-storage
          persistentVolumeClaim:
            claimName: #persistent volume name you enter after running script
      containers:
        - name: task-pv-container
          image: nginx
          ports:
            - containerPort: 80
              name: "http-server"
          volumeMounts:
            - mountPath: "/usr/share/nginx/html"
              name: task-pv-storage

     kubectl apply -f https://k8s.io/examples/pods/storage/pv-pod.yaml
    
Verify that the container in the Pod is running;

    kubectl get pod task-pv-pod


Get a shell to the container running in your Pod:

    kubectl exec -it task-pv-pod -- /bin/bash
In your shell, verify that nginx is serving the index.html file from the hostPath volume:

    # Be sure to run these 3 commands inside the root shell that comes from
    # running "kubectl exec" in the previous step
    apt update
    apt install curl
    curl http://localhost/
The output shows the text that you wrote to the index.html file on the hostPath volume:

    Hello from Kubernetes storage

If you see that message, you have successfully configured a Pod to use storage from a PersistentVolumeClaim

# You can create presistent volume locally like create /mnt/data directory

    # This assumes that your Node uses "sudo" to run commands
    # as the superuser
    sudo mkdir /mnt/dat
    
In the /mnt/data directory, create an index.html file:

    # This again assumes that your Node uses "sudo" to run commands
    # as the superuser
    sudo sh -c "echo 'Hello from Kubernetes storage' > /mnt/data/index.html"
 Create persistent volume with path "/mnt/data"
 
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: task-pv-volume
      labels:
        type: local
    spec:
      storageClassName: manual
      capacity:
        storage: 10Gi
      accessModes:
        - ReadWriteOnce
      hostPath:
        path: "/mnt/data"
        
    kubectl apply -f https://k8s.io/examples/pods/storage/pv-volume.yaml
<b>create persistent volume claim</b>

    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: task-pv-claim
    spec:
      storageClassName: manual
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 3Gi
    kubectl apply -f https://k8s.io/examples/pods/storage/pv-claim.yaml
    
Look again at the PersistentVolume:

    kubectl get pv task-pv-volume
    
Create a pod

    apiVersion: v1
    kind: Pod
    metadata:
      name: task-pv-pod
    spec:
      volumes:
        - name: task-pv-storage
          persistentVolumeClaim:
            claimName: task-pv-claim
      containers:
        - name: task-pv-container
          image: nginx
          ports:
            - containerPort: 80
              name: "http-server"
          volumeMounts:
            - mountPath: "/usr/share/nginx/html"
              name: task-pv-storage
     kubectl apply -f https://k8s.io/examples/pods/storage/pv-pod.yaml
Get a shell to the container running in your Pod:

    kubectl exec -it task-pv-pod -- /bin/bash

In your shell, verify that nginx is serving the index.html file from the hostPath volume:

    # Be sure to run these 3 commands inside the root shell that comes from
    # running "kubectl exec" in the previous step
    apt update
    apt install curl
    curl http://localhost/

The output shows the text that you wrote to the index.html file on the hostPath volume:

    Hello from Kubernetes storage

   



    
        



