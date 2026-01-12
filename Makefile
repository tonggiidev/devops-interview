# ==============================================================================
# 🛠️ Configuration & Variables
# ==============================================================================
# Versions
ARGOCD_CHART_VERSION   := 9.2.4
ROLLOUTS_CHART_VERSION := 2.40.5

# Paths & Directories
NAMESPACE       := argocd
HELM_VALUES     := platform/argocd/values.yaml
ROLLOUTS_VALUES := platform/argo-rollouts/values.yaml
ENV             := production

# App Details
APP_NAME   := go-sample-app
IMAGE_REPO := pazzii/$(APP_NAME)
TAG        := latest

# Default Goal
.DEFAULT_GOAL := help

# ==============================================================================
# 📝 Help
# ==============================================================================
.PHONY: help
help: ## 💬 Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ==============================================================================
# 🏗️ Infrastructure (Terragrunt)
# ==============================================================================
.PHONY: infra-init infra-plan infra-apply infra-destroy

infra-init: ## 🧱 Initialize Terragrunt
	cd infrastructure/environments/$(ENV) && terragrunt run-all init

infra-plan: ## 📋 Plan Infrastructure changes
	cd infrastructure/environments/$(ENV) && terragrunt run-all plan

infra-apply: ## 🚀 Apply Infrastructure changes (Create VPC & GKE)
	cd infrastructure/environments/$(ENV) && terragrunt run-all apply

infra-destroy: ## 🧨 Destroy Infrastructure (Danger!)
	cd infrastructure/environments/$(ENV) && terragrunt run-all destroy

# ==============================================================================
# ⚙️ Platform (Helm & Add-ons)
# ==============================================================================
.PHONY: install-argocd uninstall-argocd get-argocd-pass argocd-ui
.PHONY: install-rollouts uninstall-rollouts rollouts-ui bootstrap-platform

install-argocd: ## 💿 Install ArgoCD via Helm
	@echo "🟢 Installing ArgoCD (Version: $(ARGOCD_CHART_VERSION))..."
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install argocd argo/argo-cd \
		--namespace $(NAMESPACE) \
		--version $(ARGOCD_CHART_VERSION) \
		-f $(HELM_VALUES) \
		--wait
	@echo "✅ ArgoCD Installed!"

uninstall-argocd: ## 🗑️ Uninstall ArgoCD
	@echo "🔴 Uninstalling ArgoCD..."
	helm uninstall argocd -n $(NAMESPACE)
	kubectl delete namespace $(NAMESPACE)
	@echo "✅ ArgoCD Uninstalled!"

get-argocd-pass: ## 🔑 Get ArgoCD Admin Password
	@echo "🔐 ArgoCD Admin Password:"
	@kubectl -n $(NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo ""

argocd-ui: ## 🌐 Port-forward ArgoCD UI (localhost:8080)
	@echo "🚀 Opening ArgoCD UI at http://localhost:8080"
	@echo "   User: admin"
	@echo "   Pass: (Run 'make get-argocd-pass')"
	@kubectl port-forward svc/argocd-server -n $(NAMESPACE) 8080:443

install-rollouts: ## 🐣 Install Argo Rollouts via Helm
	@echo "🟢 Installing Argo Rollouts (Version: $(ROLLOUTS_CHART_VERSION))..."
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install argo-rollouts argo/argo-rollouts \
		--namespace argo-rollouts \
		--version $(ROLLOUTS_CHART_VERSION) \
		-f $(ROLLOUTS_VALUES) \
		--wait
	@echo "✅ Argo Rollouts Installed!"

uninstall-rollouts: ## 🗑️ Uninstall Argo Rollouts
	@echo "🔴 Uninstalling Argo Rollouts..."
	helm uninstall argo-rollouts -n argo-rollouts
	kubectl delete namespace argo-rollouts
	@echo "✅ Argo Rollouts Uninstalled!"

rollouts-ui: ## 📊 Port-forward Argo Rollouts Dashboard
	@echo "🚀 Opening Rollouts Dashboard at http://localhost:3100"
	@echo "   (No password required - uses your Kubeconfig)"
	@kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100

bootstrap-platform: install-argocd install-rollouts ## 📦 Install all platform components

# ==============================================================================
# 🐳 Application Development
# ==============================================================================
.PHONY: run fmt vet test docker-build docker-push clean

run: ## 🏃 Run Go app locally
	cd app && go run main.go

fmt: ## 🧹 Run go fmt
	cd app && go fmt ./...

vet: ## 🔍 Run go vet
	cd app && go vet ./...

test: fmt vet ## 🧪 Run Unit Tests (with fmt & vet)
	cd app && go test -v ./...

docker-build: ## 🔨 Build Docker Image
	cd app && docker build -t $(IMAGE_REPO):$(TAG) .

docker-push: ## 📤 Push Docker Image to Registry
	docker push $(IMAGE_REPO):$(TAG)

clean: ## 🗑️ Clean build artifacts
	rm -f app/app

# ==============================================================================
# 🚀 Deployment (GitOps)
# ==============================================================================
.PHONY: deploy-app get-argocd-pass argocd-ui

deploy-app: ## 🚢 Deploy Application via ArgoCD
	kubectl apply -f argocd/production.yaml
	@echo "✅ Application manifest submitted to ArgoCD!"
