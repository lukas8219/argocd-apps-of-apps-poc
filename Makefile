.PHONY: serve argocd-bootstrap kind-start kind-stop argocd-access help

help:
	@echo "Available commands:"
	@echo "  serve            - Serve current directory using Python HTTP server"
	@echo "  argocd-bootstrap - Install ArgoCD in current Kubernetes context and apply root app"
	@echo "  kind-start       - Start a Kind cluster with 1 control-plane and 2 worker nodes"
	@echo "  kind-stop        - Stop the Kind cluster"
	@echo "  argocd-access    - Print ArgoCD admin password and set up port-forwarding"

serve:
	@echo "Starting Python HTTP server on port 8000..."
	python3 -m http.server 8000

argocd-bootstrap:
	@echo "Creating ArgoCD namespace..."
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@echo "Installing ArgoCD..."
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "Waiting for ArgoCD server to be ready..."
	kubectl wait --for=condition=available --timeout=300s -n argocd deployment/argocd-server
	@echo "Applying root application..."
	kubectl apply -f argocd/root-app.yaml
	@echo "ArgoCD installed successfully. Getting the admin password..."
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
	@echo "Access ArgoCD UI by running: kubectl port-forward svc/argocd-server -n argocd 8080:443"

argocd-access:
	@echo "ArgoCD Admin Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
	@echo "Setting up port-forwarding to ArgoCD UI at http://localhost:8080..."
	@echo "Press Ctrl+C to stop port-forwarding"
	kubectl port-forward svc/argocd-server -n argocd 8080:443

kind-start:
	@echo "Creating kind-config.yaml with 1 control-plane and 2 worker nodes..."
	@echo "kind: Cluster" > kind-config.yaml
	@echo "apiVersion: kind.x-k8s.io/v1alpha4" >> kind-config.yaml
	@echo "nodes:" >> kind-config.yaml
	@echo "- role: control-plane" >> kind-config.yaml
	@echo "  extraPortMappings:" >> kind-config.yaml
	@echo "  - containerPort: 80" >> kind-config.yaml
	@echo "    hostPort: 80" >> kind-config.yaml
	@echo "  - containerPort: 443" >> kind-config.yaml
	@echo "    hostPort: 443" >> kind-config.yaml
	@echo "- role: worker" >> kind-config.yaml
	@echo "- role: worker" >> kind-config.yaml
	@echo "Starting Kind cluster with config..."
	kind create cluster --config kind-config.yaml
	@echo "Configuring cluster to access host services..."
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@echo "Cluster is ready. Node status:"
	kubectl get nodes

kind-stop:
	@echo "Stopping Kind cluster..."
	kind delete cluster
	@echo "Removing kind-config.yaml..."
	rm -f kind-config.yaml 