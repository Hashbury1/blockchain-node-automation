#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════╗"
echo "║   Blockchain Node AWS Deployment                   ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check prerequisites
print_info "Checking prerequisites..."

command -v aws >/dev/null 2>&1 || { print_error "AWS CLI not found. Install from https://aws.amazon.com/cli/"; exit 1; }
command -v terraform >/dev/null 2>&1 || { print_error "Terraform not found. Install from https://www.terraform.io/downloads"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { print_error "kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/"; exit 1; }
command -v helm >/dev/null 2>&1 || { print_error "Helm not found. Install from https://helm.sh/docs/intro/install/"; exit 1; }

print_success "All prerequisites met"

# Verify AWS credentials
print_info "Verifying AWS credentials..."
aws sts get-caller-identity > /dev/null 2>&1 || { print_error "AWS credentials not configured. Run 'aws configure'"; exit 1; }
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_success "AWS Account: $AWS_ACCOUNT_ID"

# Set variables
REGION=${AWS_REGION:-us-east-1}
CLUSTER_NAME=${CLUSTER_NAME:-blockchain-node-cluster}
ENVIRONMENT=${ENVIRONMENT:-dev}

echo ""
print_info "Deployment Configuration:"
echo "  Region: $REGION"
echo "  Cluster: $CLUSTER_NAME"
echo "  Environment: $ENVIRONMENT"
echo ""

read -p "Continue with deployment? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Deploy infrastructure
print_info "Deploying infrastructure with Terraform..."

cd terraform

# Initialize Terraform
terraform init

# Plan
terraform plan \
  -var="region=$REGION" \
  -var="cluster_name=$CLUSTER_NAME" \
  -var="environment=$ENVIRONMENT" \
  -out=tfplan

read -p "Review the plan above. Apply? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Apply
terraform apply tfplan

print_success "Infrastructure deployed"

# Configure kubectl
print_info "Configuring kubectl..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Verify cluster access
kubectl get nodes

print_success "Cluster access configured"

cd ..

# Deploy Geth node
print_info "Deploying Geth node..."

kubectl apply -f k8s/geth/00-namespace.yaml
kubectl apply -f k8s/geth/01-pvc.yaml
kubectl apply -f k8s/geth/02-configmap.yaml
kubectl apply -f k8s/geth/03-statefulset.yaml
kubectl apply -f k8s/geth/04-service-aws.yaml

print_info "Waiting for Geth pod to be ready..."
kubectl wait --for=condition=ready pod -l app=geth -n eth-nodes --timeout=300s || {
    print_error "Geth pod did not become ready in time"
    kubectl get pods -n eth-nodes
    kubectl describe pod -l app=geth -n eth-nodes
    exit 1
}

print_success "Geth node deployed"

# Deploy monitoring
print_info "Deploying monitoring stack..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values k8s/monitoring/prometheus-values-aws.yaml \
  --timeout 15m \
  --wait

print_success "Monitoring stack deployed"

# Get endpoints
echo ""
print_success "Deployment Complete!"
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║   Service Endpoints                                 ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

print_info "Fetching endpoints (this may take a minute)..."
sleep 30

GETH_ENDPOINT=$(kubectl get svc geth-service -n eth-nodes -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
GRAFANA_ENDPOINT=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

echo ""
echo "📊 Geth RPC Endpoint:"
echo "   http://$GETH_ENDPOINT:8545"
echo ""
echo "📈 Grafana Dashboard:"
echo "   http://$GRAFANA_ENDPOINT"
echo "   Username: admin"
echo "   Password: changeme123!"
echo ""
echo "🔧 Prometheus:"
echo "   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo ""
echo "📝 Useful Commands:"
echo "   kubectl get pods -A                    # View all pods"
echo "   kubectl logs -f geth-node-0 -n eth-nodes   # View Geth logs"
echo "   kubectl get svc -A                     # View all services"
echo ""
print_info "Note: LoadBalancer DNS may take 2-3 minutes to propagate"
echo ""
print_success "Access your services using the endpoints above!"
echo ""
echo "⚠️  Cost Warning: This infrastructure costs approximately \$7/day"
echo "    To teardown: cd terraform && terraform destroy"
echo ""