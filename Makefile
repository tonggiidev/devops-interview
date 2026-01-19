# ==============================================================================
# 🛠️ Configuration & Variables
# ==============================================================================
# --- GCP Infrastructure ---
TF_LOG_LEVEL  := $(if $(DEBUG),DEBUG,ERROR)
PROJECT_ID  	?= <PROJECT_ID>
BUCKET_NAME 	?= <BUCKET_NAME>
REGION      	?= asia-southeast1
CLUSTER_NAME 	?= prod-cluster
ENV         	:= production

# --- Platform Versions ---
ARGOCD_CHART_VERSION   := 9.2.4
ROLLOUTS_CHART_VERSION := 2.40.5

# --- Paths ---
NAMESPACE       := argocd
HELM_VALUES     := platform/argocd/values.yaml
ROLLOUTS_VALUES := platform/argo-rollouts/values.yaml

# --- App Details ---
APP_NAME   := go-sample-app
IMAGE_REPO := pazzii/$(APP_NAME)
TAG        := latest

# ==============================================================================
# 📝 Help
# ==============================================================================
.DEFAULT_GOAL := help
.PHONY: help
help: ## 💬 Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ==============================================================================
# Setup & Prerequisites
# ==============================================================================
.PHONY: setup-gcp infra-setup-bucket connect-cluster

setup-gcp: ## 🔐 Login to GCP & Setup Project
	@echo "🔐 Logging in to Google Cloud..."
	gcloud auth application-default login
	gcloud config set project $(PROJECT_ID)
	@echo "✅ GCP Setup Complete!"

infra-setup-bucket: ## 🪣 Create Terraform State Bucket (Manual Step)
	@echo "🪣 Creating Terraform State Bucket: gs://$(BUCKET_NAME)..."
	@gcloud storage buckets create gs://$(BUCKET_NAME) --project=$(PROJECT_ID) --location=$(REGION) \
	|| echo "⚠️ Bucket might already exist. Skipping..."

connect-cluster: ## 🔌 Get Kubeconfig for GKE Cluster
	@echo "🔌 Connecting to GKE Cluster..."
	gcloud container clusters get-credentials $(CLUSTER_NAME) --region $(REGION) --project $(PROJECT_ID)
	@echo "✅ Connected to $(CLUSTER_NAME)!"

# ==============================================================================
# Infrastructure (Terragrunt)
# ==============================================================================
.PHONY: infra-init infra-plan infra-apply infra-destroy

infra-init: ## 🧱 Initialize Terragrunt
	cd infrastructure/environments/$(ENV) && terragrunt init

infra-plan: ## 📋 Plan Infrastructure changes
	cd infrastructure/environments/$(ENV) && terragrunt plan



infra-apply: ## 🚀 Apply Infrastructure changes (Create VPC & GKE)
	cd infrastructure/environments/$(ENV) && TF_LOG=$(TF_LOG_LEVEL) terragrunt apply

infra-destroy: ## 🧨 Destroy Infrastructure (Danger!)
	cd infrastructure/environments/$(ENV) && terragrunt destroy

# ==============================================================================
# Platform (Helm & Add-ons)
# ==============================================================================
.PHONY: install-argocd uninstall-argocd get-argocd-pass argocd-ui
.PHONY: install-rollouts uninstall-rollouts rollouts-ui bootstrap-platform

install-argocd: ## 💿 Install ArgoCD via Helm
	@echo "🟢 Installing ArgoCD..."
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install argocd argo/argo-cd \
		--namespace $(NAMESPACE) \
		--version $(ARGOCD_CHART_VERSION) \
		-f $(HELM_VALUES) \
		--wait
	@echo "✅ ArgoCD Installed!"

get-argocd-pass: ## 🔑 Get ArgoCD Admin Password
	@echo "🔐 ArgoCD Admin Password:"
	@kubectl -n $(NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo ""

argocd-ui: ## 🌐 Port-forward ArgoCD UI (localhost:8080)
	@echo "🚀 Opening ArgoCD UI at http://localhost:8080 (User: admin)"
	@kubectl port-forward svc/argocd-server -n $(NAMESPACE) 8080:443

install-rollouts: ## 🐣 Install Argo Rollouts via Helm
	@echo "🟢 Installing Argo Rollouts..."
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install argo-rollouts argo/argo-rollouts \
		--namespace argo-rollouts \
		--version $(ROLLOUTS_CHART_VERSION) \
		-f $(ROLLOUTS_VALUES) \
		--wait
	@echo "✅ Argo Rollouts Installed!"

rollouts-ui: ## 📊 Port-forward Argo Rollouts Dashboard (localhost:3100)
	@echo "🚀 Opening Rollouts Dashboard at http://localhost:3100"
	@kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100

bootstrap-platform: install-argocd install-rollouts ## 📦 Install ALL platform components

# ==============================================================================
# Application Development (Go/Docker)
# ==============================================================================
.PHONY: run fmt vet test docker-build docker-push clean

run: ## 🏃 Run Go app locally
	cd app && go run main.go

test: ## 🧪 Run Unit Tests
	cd app && go fmt ./... && go vet ./... && go test -v ./...

docker-build: ## 🔨 Build Docker Image
	cd app && docker build -t $(IMAGE_REPO):$(TAG) .

docker-push: ## 📤 Push Docker Image to Registry
	docker push $(IMAGE_REPO):$(TAG)

# ==============================================================================
# Deployment (GitOps)
# ==============================================================================
.PHONY: deploy-app

deploy-app: ## 🚢 Submit Application to ArgoCD
	kubectl apply -f argocd/production.yaml
	@echo "✅ Application manifest submitted to ArgoCD!"

# ==============================================================================
# 🚀 Full Stack Shortcuts
# ==============================================================================
.PHONY: all-infra all-platform

all-infra: setup-gcp infra-setup-bucket infra-init infra-apply connect-cluster ## 🏗️ Build entire Infrastructure from scratch
all-platform: bootstrap-platform ## 📦 Install all Platform tools
