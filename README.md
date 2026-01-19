# Go Sample App with GKE, GitOps, and Canary Deployment

This repository demonstrates a complete **DevOps/SRE workflow** for deploying a Golang application. It implements **Infrastructure as Code (IaC)** using Terragrunt/Terraform on Google Kubernetes Engine (GKE), adopts **GitOps** principles with ArgoCD, and utilizes **Progressive Delivery (Canary)** via Argo Rollouts.

## 🏗 Architecture & Tech Stack

- **Application:** Golang (REST API) packaged in a distroless container for security.
- **Infrastructure:** Google Kubernetes Engine (Regional Cluster for HA).
- **IaC:** Terraform & Terragrunt (DRY principle).
- **CI/CD:** GitHub Actions (CI) + ArgoCD (CD).
- **Deployment Strategy:** Canary Deployment (Argo Rollouts) with automated Analysis.
- **Configuration Management:** Kustomize.
- **Observability & Cost:** Resource Labeling for precise GCP billing visibility.

## 📂 Project Structure

```bash
.
├── app/                  # Golang source code & Dockerfile (Multi-stage)
├── infrastructure/       # Terraform modules & Terragrunt configurations
│   ├── environments/     # Environment-specific config (production)
│   └── modules/          # Reusable Terraform modules (GKE, VPC)
├── k8s/                  # Kubernetes manifests
│   ├── base/             # Base manifests (Rollout, Service, Analysis)
│   └── overlays/         # Environment patches (Kustomize)
├── platform/             # Helm values for Platform tools (ArgoCD, Rollouts)
├── argocd/               # ArgoCD Application manifests (App of Apps pattern)
└── .github/workflows/    # CI Pipeline definition

```

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed:

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`)
- [Terraform](https://www.terraform.io/) & [Terragrunt](https://terragrunt.gruntwork.io/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- `gke-gcloud-auth-plugin`

### 1. Provision Infrastructure

We use Terragrunt to manage GKE clusters. The setup includes a Regional Cluster (3 zones) with Cost-Optimized VMs (`n2d-standard`).

```bash
# Initialize and Apply Infrastructure
make infra-init
make infra-apply

# Verify connectivity
make connect-cluster
kubectl get nodes

```

> **Note:** The infrastructure includes `resource_labels` for granular cost tracking (e.g., `cost_center=devops-team`).

### 2. Install Platform Tools

Deploy ArgoCD and Argo Rollouts to the cluster.

```bash
# Install ArgoCD
make install-argocd

# Install Argo Rollouts
make install-rollouts

```

### 3. Deploy the Application (GitOps)

Apply the ArgoCD application manifest to start the GitOps synchronization.

```bash
kubectl apply -f argocd/production.yaml

```

ArgoCD will detect the manifests in `k8s/overlays/production` and deploy the application.

## 🔄 CI/CD Workflow

The pipeline is fully automated using GitHub Actions and GitOps:

1. **Code Change:** Developer pushes code to `main`.
2. **CI (GitHub Actions):**

- Builds the Go binary.
- Builds Docker image using caching.
- Pushes image to Registry (tagged with SHA).
- **Updates Kustomize:** Automatically updates the image tag in `k8s/overlays/production/kustomization.yaml` and commits the change back to the repo.

3. **CD (ArgoCD):** Detects the configuration change and syncs the cluster state.
4. **Progressive Delivery (Argo Rollouts):**

- Rollout starts.
- **Step 1:** Traffic shift to 20% -> Pause 30s.
- **Analysis:** Runs `smoke-test` (curl check).
- **Step 2:** Traffic shift to 50% -> Pause 30s.
- **Step 3:** Traffic shift to 100%.

## 🛡 Security & Best Practices

- **Distroless Image:** The app runs as a non-root user (`USER 65532`) in a container with no shell.
- **High Availability:** Regional GKE cluster spans 3 zones.
- **Cost Management:**
- Uses Spot/Preemptible friendly config (though currently on-demand for stability).
- Full resource labeling for billing reports.

- **Zero-Downtime:** `lifecycle { create_before_destroy = true }` is used where applicable to prevent outages during infra updates.

## 💰 Cost Monitoring

Resources are tagged for billing allocation. You can filter GCP Billing Reports using:

- `project: assignment-interview`
- `cost_center: devops-team`
- `env: production`

---
