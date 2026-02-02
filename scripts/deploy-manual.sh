#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_header() {
    echo -e "${GREEN}"
    echo "=========================================="
    echo " Blockchain Node Automation Platform"
    echo " (Manual Deployment Mode)"
    echo "=========================================="
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v k3d >/dev/null 2>&1 || missing_tools+=("k3d")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

create_cluster() {
    print_step "Step 1: Creating k3d cluster..."
    
    if k3d cluster list | grep -q blockchain-lab; then
        print_info "Cluster already exists, skipping creation"
    else
        k3d cluster create blockchain-lab \
          --agents 2 \
          --port "8545:30545@loadbalancer" \
          --port "8332:30332@loadbalancer" \
          --port "3000:30000@loadbalancer" \
          --wait
        
        print_success "Cluster created successfully"
    fi
    
    # Wait for cluster to be ready
    print_info "Waiting for cluster to be ready..."
    sleep 10
    kubectl wait --for=condition=Ready nodes --all --timeout=60s
}

deploy_monitoring() {
    print_step "Step 2: Deploying monitoring stack (this may take 5-10 minutes)..."
    
    # Create namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Add Helm repo
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update
    
    print_info "Installing Prometheus stack (be patient, this takes time)..."
    
    # Deploy with longer timeout and no wait initially
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --values "$PROJECT_ROOT/k8s/monitoring/prometheus-values.yaml" \
      --timeout 15m \
      --wait \
      --debug 2>&1 | grep -E "(NOTES|STATUS|deployed|ready)" || true
    
    print_success "Monitoring stack deployed"
    
    # Wait for critical pods
    print_info "Waiting for Grafana to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s || {
        print_error "Grafana is taking longer than expected. Continuing anyway..."
    }
}

deploy_node() {
    local node_type=$1
    
    print_step "Step 3: Deploying $node_type node..."
    
    case $node_type in
        geth)
            kubectl apply -f "$PROJECT_ROOT/k8s/geth/"
            print_info "Waiting for Geth pod to be created..."
            sleep 5
            kubectl wait --for=condition=ready pod -l app=geth -n eth-nodes --timeout=180s 2>/dev/null || {
                print_info "Geth is starting (may take a few minutes to be ready)"
            }
            ;;
        bitcoin)
            kubectl apply -f "$PROJECT_ROOT/k8s/bitcoin/"
            print_info "Waiting for Bitcoin pod to be created..."
            sleep 5
            kubectl wait --for=condition=ready pod -l app=bitcoin -n btc-nodes --timeout=180s 2>/dev/null || {
                print_info "Bitcoin is starting (may take a few minutes to be ready)"
            }
            ;;
        all)
            kubectl apply -f "$PROJECT_ROOT/k8s/geth/"
            kubectl apply -f "$PROJECT_ROOT/k8s/bitcoin/"
            print_info "Both nodes deployed, waiting for them to start..."
            sleep 10
            ;;
    esac
    
    print_success "$node_type node deployed"
}

show_access_info() {
    echo ""
    echo -e "${GREEN}=========================================="
    echo "Deployment Complete!"
    echo -e "==========================================${NC}"
    echo ""
    echo "📊 Access your services:"
    echo ""
    echo "  Grafana Dashboard:"
    echo "    http://localhost:3000"
    echo "    Username: admin"
    echo "    Password: prom-operator"
    echo ""
    echo "  Prometheus:"
    echo "    http://localhost:9090"
    echo ""
    
    if [[ "$1" == "geth" ]] || [[ "$1" == "all" ]]; then
        echo "  Geth (Ethereum Sepolia):"
        echo "    RPC: http://localhost:8545"
        echo ""
    fi
    
    if [[ "$1" == "bitcoin" ]] || [[ "$1" == "all" ]]; then
        echo "  Bitcoin (Testnet):"
        echo "    RPC: http://localhost:8332"
        echo ""
    fi
    
    echo "📝 Useful commands:"
    echo "  Check status:   ./scripts/check-sync.sh"
    echo "  View pods:      kubectl get pods -A"
    echo "  View logs:      kubectl logs -f <pod-name> -n <namespace>"
    echo "  Cleanup:        ./scripts/cleanup.sh"
    echo ""
}

show_usage() {
    cat << EOF
Usage: $0 [NODE_TYPE]

Deploy blockchain nodes to local Kubernetes cluster (manual mode).

NODE_TYPE options:
  geth      Deploy Ethereum (Geth) node on Sepolia testnet
  bitcoin   Deploy Bitcoin node on testnet
  all       Deploy both Geth and Bitcoin nodes

This script is more verbose and handles timeouts better than the Ansible version.

Examples:
  $0 geth      # Deploy only Ethereum node
  $0 bitcoin   # Deploy only Bitcoin node
  $0 all       # Deploy both nodes

EOF
}

main() {
    local node_type=${1:-geth}
    
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    if [[ ! "$node_type" =~ ^(geth|bitcoin|all)$ ]]; then
        print_error "Invalid node type: $node_type"
        echo ""
        show_usage
        exit 1
    fi
    
    print_header
    check_prerequisites
    create_cluster
    deploy_monitoring
    deploy_node "$node_type"
    show_access_info "$node_type"
}

main "$@"