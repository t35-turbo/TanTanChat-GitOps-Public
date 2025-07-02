# T3 Cloneathon GitOps Repository

Ever wanted to have scalability and deploy TanTan chat on a kubernetes cluter with probably higher uptime than the actual models that the backend interacts with on OpenRouter for some reason??? Deploy on Kubernetes!!11!11!1!11!1!!!

This repository contains Kubernetes manifests for deploying TanTan chat with using GitOps principles and ArgoCD.

### "I want to deploy fast"
There's a vibe coded untested setup.sh script in this repo that'll *probably* work

![Machine Learning](https://imgs.xkcd.com/comics/machine_learning.png)

*Image source: [xkcd: Machine Learning](https://xkcd.com/1838/)*

\- from the frontend guy: akshually just make vershell do it


## Architecture

The application consists of the following service definitions:
- **Frontend**: TanTan chat UI
- **Backend**: TanTan chat API server (built with Hono + BetterAuth + Drizzle ORM)
- **Database**: PostgreSQL
- **Cache, streaming**: Redis
- **Storage**: Persistent volumes for file uploads, PostgreSQL, and Redis
- **Ingress**: NGINX ingress controller with TLS

## Prerequisites

- Kubernetes cluster
- ArgoCD installed and configured (we are lazy clickOps admins)
- NGINX Ingress Controller
- cert-manager (for TLS certificate provisioning)
- kubectl configured to access your cluster

## Setup

### 0. Fork the code branch for GitHub Actions and package builds
This repository contains kubernetes manifests and configurations for deploying the application. You'll need to fork the other repository in order to be able to have CI.

### 1. Fork and Clone

1. Fork this repository to your GitHub account
2. Clone your forked repository:
```bash
git clone https://github.com/YOUR_USERNAME/YOUR_GITOPS_REPO.git
cd YOUR_GITOPS_REPO
```

### 2. Configure Repository URL

Update the ArgoCD application manifest:
```bash
# Edit argocd/application.yaml
# Replace YOUR_USERNAME and YOUR_GITOPS_REPO with your values
```

### 3. Configure Secrets, Storage, and Replication

Before deploying, you need to update the secret values:

#### Application Secrets (`manifests/secret/secret.yaml`)
Replace the placeholder values with base64-encoded secrets (or create them using `kubectl` on your cluster):

NOTE: ECHO APPENDS A NEWLINE CHARACTER AT THE END, DON'T BE LIKE ME AND SPEND HOURS DEBUGGING :sob: - Pablonara

```bash
# Generate base64 encoded values for your secrets
echo -n "your_postgres_password" | base64
echo -n "your_redis_password" | base64
echo -n "your_better_auth_secret" | base64
echo -n "your_discord_client_id" | base64
echo -n "your_discord_client_secret" | base64
```

#### Image Pull Secret (`manifests/secret/image-pull-secret.yaml`)
Update with your GitHub credentials:
- Replace `YOUR_GITHUB_USERNAME` with your GitHub username
- Replace `YOUR_GITHUB_TOKEN` with your GitHub Personal Access Token

Alternatively, create the secret using kubectl:
```bash
kubectl create secret docker-registry ghcr-io-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_TOKEN \
  --namespace=t3-cloneathon
```

#### Replication
You can adjust the number of replicas for the backend and frontend deployments in their respective manifest files

Consider using Postgres and Redis operators and verify Redis setup for clustered deployments

#### Persistient Volumes
The example uses local storage for persistient volumes, under the assumption you have some sort of CEPH/glusterFS/DRBD/similar or NFS backed storage infrastructure. If you are deploying on a cloud provider and not bare metal (e.g. AWS), they likely have their own storage classes (e.g.) you can use. You should consult the provider's documentation.


### 4. Configure Container Images

Update the image references in:
- `manifests/backend/deployment.yaml`
- `manifests/frontend/deployment.yaml`

Replace `YOUR_USERNAME` with your GitHub username. The default images point to `ghcr.io/YOUR_USERNAME/t3-cloneathon/backend:latest` and `ghcr.io/YOUR_USERNAME/t3-cloneathon/frontend:latest`.

### 5. Update Kustomization Manifest and container images to point to your fork

Review and update the `manifests/kustomization.yaml` file to ensure all the resources you want to deploy are included. The kustomization file controls which manifests are applied to your cluster.

By default, all necessary resources are included, but you may want to:
- Add or remove specific resources based on your needs
- Modify the namespace if you want to use a different one
- Add any additional configurations or patches

```bash
# Review the kustomization file
cat manifests/kustomization.yaml

# Test the kustomization builds correctly
kubectl kustomize manifests/
```

### 6. Configure Domain

Update your domain name in:
- `manifests/configmap/configmap.yaml` (BETTER_AUTH_URL)
- `manifests/backend/deployment.yaml` (FRONTEND_URL)
- `manifests/ingress/ingress.yaml` (host and TLS)

### 7. Deploy with ArgoCD

1. Apply the ArgoCD application (UI or CLI):
```bash
kubectl apply -f argocd/application.yaml
```

2. Sync the application in ArgoCD UI or CLI:
```bash
argocd app sync t3-cloneathon
```

## Repository Structure

```
├── README.md
├── argocd/
│   └── application.yaml          # ArgoCD application definition
└── manifests/
    ├── kustomization.yaml        # Kustomize configuration
    ├── backend/
    │   └── deployment.yaml       # Backend deployment, service, and PVC
    ├── configmap/
    │   └── configmap.yaml        # Application configuration
    ├── frontend/
    │   └── deployment.yaml       # Frontend deployment and service
    ├── ingress/
    │   └── ingress.yaml          # Ingress configuration
    ├── namespace/
    │   └── namespace.yaml        # Namespace definition
    ├── postgres/
    │   └── postgres.yaml         # PostgreSQL deployment and service
    ├── redis/
    │   ├── redis.yaml            # Redis deployment
    │   └── redis-service.yml     # Redis service
    ├── secret/
    │   ├── image-pull-secret.yaml # Docker registry secret
    │   └── secret.yaml           # Application secrets
    └── storage/
        ├── persistent-volumes.yaml # Persistent volumes
        └── storageclass.yaml     # Storage class definition
```

## Configuration

### Environment Variables

The application uses the following environment variables configured via ConfigMap and Secrets:

**ConfigMap (`app-config`):**
- `NODE_ENV`: Application environment (production)
- `POSTGRES_DB`: Database name
- `POSTGRES_USER`: Database user
- `POSTGRES_PORT`: Database port
- `REDIS_HOST`: Redis host
- `REDIS_PORT`: Redis port
- `REDIS_URL`: Full Redis connection URL
- `SERVER_PORT`: Backend server port
- `LOCAL_FILE_STORE_PATH`: File storage path
- `BETTER_AUTH_URL`: Authentication service URL

**Secrets (`app-secrets`):**
- `POSTGRES_PASSWORD`: Database password
- `REDIS_PASSWORD`: Redis password ~~(optional)~~ Kubernetes won't allow empty secrets AFAIK
- `BETTER_AUTH_SECRET`: Authentication secret key
- `DISCORD_CLIENT_ID`: Discord OAuth client ID
- `DISCORD_CLIENT_SECRET`: Discord OAuth client secret

### Storage (EDIT THE STORAGE DEFINITIONS TO AVOID HEADACHES UNLESS YOU HAVE THE EXACT SAME SETUP AS TANTAN PROD FOR SOME REASON)

The application uses persistent storage for:
- **Backend uploads**: 0.5Gi persistent volume for file storage
- **PostgreSQL data**: Database persistence
- **Redis data**: Cache persistence

### Networking

You'll probably want a loadbalancer for HA. Here are the default internal ports used by the services:

- **Ingress**: NGINX Ingress Controller with TLS termination bound to the domain specified in the ConfigMap.
- **Frontend**: Internally bound on port 80
- **Backend**: Internally bound on port 3001
- **Database**: Internal service on port 5432
- **Redis**: Internal service on port 6379

