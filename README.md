# Hetzner K3s Cluster - Easy Deployment with OpenTofu

A project that makes setting up lightweight Kubernetes clusters on Hetzner Cloud a breeze. Deploy, scale, and manage your K3s cluster with simple commands!

## What's this all about?

This project helps you quickly spin up a K3s cluster on Hetzner Cloud. It automates everything from infrastructure provisioning to Kubernetes configuration, so you can focus on what matters - running your applications.

## What is K3s?

K3s is like Kubernetes on a diet - it's a lightweight, fully compliant Kubernetes distribution that requires just half the memory of standard K8s. Created by Rancher Labs (now part of SUSE), K3s packs the full Kubernetes experience into a single binary under 100MB!

Some cool things about K3s:
- Super easy to install and manage
- Runs great on resource-constrained hardware
- Uses SQLite as the default database (simpler than etcd)
- Strips out unnecessary features to stay lean and fast
- Perfect for edge computing, IoT, and development environments

## Why Hetzner Cloud?

Hetzner offers some of the best bang-for-buck cloud servers out there. Based in Germany, they provide:
- Really affordable VPS options that don't skimp on performance
- Data centers in Germany, Finland, Singapur and the USA
- A straightforward API that's perfect for automation
- S3-compatible object storage for your state files and data
- Pay only for what you use with no hidden fees

## How it's organized

This project handles the entire workflow:

1. **Infrastructure:** OpenTofu (the open-source Terraform alternative) spins up your VMs, configures networks, and sets up security.

2. **Kubernetes (K3S):** Ansible takes care of installing K3s on all nodes and configuring them properly.

Here's what's in the box:
 ```bash
.
├── LICENSE
├── README.md
├── ansible
│   ├── ansible.cfg
│   ├── inventory
│   ├── roles
│   │   ├── common
│   │   │   └── tasks
│   │   │       └── main.yml
│   │   ├── k3s_master
│   │   │   └── tasks
│   │   │       └── main.yml
│   │   └── k3s_worker
│   │       └── tasks
│   │           └── main.yml
│   └── site.yml
├── scripts
│   ├── deploy.sh
│   └── destroy.sh
└── tofu
    ├── backend.tf
    ├── backend.tfvars
    ├── main.tf
    ├── outputs.tf
    ├── providers.tf
    ├── templates
    │   └── inventory.tpl
    ├── variables.tf
    └── versions.tf
```

## Getting started

### What you'll need

Before diving in, make sure you have:

1. **A Hetzner Cloud account** - Sign up at [https://www.hetzner.com/cloud](https://www.hetzner.com/cloud) if you don't have one yet.

2. **A Hetzner API token** - We'll need this to create resources programmatically.

3. **Some tools installed locally:**
   - OpenTofu
   - Ansible
   - jq
   - kubectl

### Setting up Hetzner Object Storage

We'll use Hetzner's S3-compatible storage to keep track of our infrastructure state. Here's how to set it up:

1. **Create your storage:**
   - Log into the [Hetzner Cloud Console](https://console.hetzner.cloud)
   - Navigate to "Storage" > "Object Storage" in the sidebar
   - Click "Create Object Storage" 
   - Pick a location close to where you'll run your cluster
   - Hit "Create & Buy Now"

2. **Generate access keys:**
   - Click on your new storage in the overview
   - Go to the "Access Keys" tab
   - Click "Generate Key"
   - Save both keys somewhere safe - the secret key only shows once!

3. **Create a bucket for your state files:**
   - Click over to the "Buckets" tab
   - Click "Create Bucket"
   - Give it a name you'll remember (like "k3s-cluster-state")
   - For permissions, "Private" is usually best for state files
   - Click "Create"

4. **Make note of these details:**
   - Your bucket name
   - The endpoint URL (looks like `https://fsn1.your-objectstorage.com`)
   - The region (like "eu-central" for Falkenstein, Germany)

5. **Set up your environment variables:**
   ```bash
   export AWS_ACCESS_KEY_ID=your_access_key
   export AWS_SECRET_ACCESS_KEY=your_secret_key
   export HCLOUD_TOKEN=your_hetzner_api_token
   ```


### Configuring the backend

Now let's tell OpenTofu where to store its state:

1. **Create a backend.tfvars file:**
   Create a file with your storage details:

   ```hcl
   bucket   = "your-bucket-name"
   key      = "hcloud/k3s/tofu.tfstate"
   endpoint = "https://fsn1.your-objectstorage.com"
   region   = "eu-central"
   ```
   This file contains your personal config, so don't commit it to public repos!

2. **Initialize OpenTofu with your config:**
   ```bash
   cd tofu
   tofu init -backend-config=backend.tfvars
   ```
   This sets up OpenTofu to use your Hetzner storage.

## Running the scripts
### Deploy your cluster
Want to spin up your cluster? Just run:
```bash
./scripts/deploy.sh
```
This creates a cluster with one master and one worker node by default.
Need more worker nodes? Just specify how many:
```bash
./scripts/deploy.sh 3
```

This gives you one master and three workers.
Behind the scenes, the script:

1. Plans out the infrastructure changes
2. Creates all the needed resources on Hetzner
3. Installs K3s on each node
4. Removes any outdated nodes when scaling down
5. Shows you the final cluster status and how to connect

### Scale your cluster up or down
Need more capacity? Just run the deploy script with a higher number:
```bash
./scripts/deploy.sh 5
```
Need to scale down to save costs? Just run with a lower number:
```bash
./scripts/deploy.sh 2
```
The script is smart enough to:
1. Update only what's necessary
2. Properly drain and remove nodes that are no longer needed
3. Keep your master node untouched

### Tear it all down
Done with your cluster? Clean everything up with:
```bash
./scripts/destroy.sh
```

When prompted, type "yes-destroy-everything" to confirm.
The script carefully removes resources in the right order to avoid dependency errors.
## Troubleshooting
### Common hiccups and fixes

1. **Node stuck in NotReady state?** The cleanup script should catch these, but if not:
```bash
kubectl drain problem-node --ignore-daemonsets --delete-emptydir-data --force
kubectl delete node problem-node
```

2. **Getting "network has attached resources" errors?** The destroy script tries to handle this, but if you still see it:

```bash
# Manually delete servers first
tofu destroy -target="hcloud_server.worker" -target="hcloud_server.master"
# Then try the full destroy again
./scripts/destroy.sh
```

3. **Can't use kubectl after deployment?** Copy the kubeconfig file to where kubectl expects it:
```bash
cp ansible/k3s.yaml ~/.kube/config
```

4. **Backend config issues?**
Double-check that:

- Your backend.tfvars has the right info
- You've exported the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY variables
- The bucket actually exists in your Hetzner Object Storage



## Need more help?

Check out these resources:
- [K3s Documentation](https://k3s.io/)
- [Hetzner Cloud Docs](https://docs.hetzner.com/cloud/)
- [OpenTofu Documentation](https://opentofu.org/docs/)

Happy clustering! 🚀
