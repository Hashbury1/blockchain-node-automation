#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_header() {
    echo -e "${GREEN}"
    echo "=========================================="
    echo " Blockchain Node Automation Platform"
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

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v k3d >/dev/null 2>&1 || missing_tools+=("k3d")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v ansible-playbook >/dev/null 2>&1 || missing_tools+=("ansible")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install missing tools:"
        echo "  k3d:     curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
        echo "  kubectl: https://kubernetes.io/docs/tasks/tools/"
        echo "  helm:    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
        echo "  ansible: pip3 install ansible --break-system-packages"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

deploy_infrastructure() {
    local node_type=$1
    
    print_info "Deploying infrastructure for: $node_type"
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook deploy-nodes.yml \
        -i inventory/hosts \
        -e "node_type=$node_type" \
        -v
    
    print_success "Deployment completed successfully"
}

show_usage() {
    cat << EOF
Usage: $0 [NODE_TYPE]

Deploy blockchain nodes to local Kubernetes cluster.

NODE_TYPE options:
  geth      Deploy Ethereum (Geth) node on Sepolia testnet
  bitcoin   Deploy Bitcoin node on testnet
  all       Deploy both Geth and Bitcoin nodes

Examples:
  $0 geth      # Deploy only Ethereum node
  $0 bitcoin   # Deploy only Bitcoin node
  $0 all       # Deploy both nodes

After deployment:
  Grafana:  http://localhost:3000 (admin/prom-operator)
  Geth RPC: http://localhost:8545
  Bitcoin:  http://localhost:8332

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
    deploy_infrastructure "$node_type"
    
    echo ""
    print_success "All services deployed!"
    echo ""
    print_info "Access your services:"
    echo "  📊 Grafana:    http://localhost:3000"
    echo "  📈 Prometheus: http://localhost:9090"
    if [[ "$node_type" == "geth" ]] || [[ "$node_type" == "all" ]]; then
        echo "  🔗 Geth RPC:   http://localhost:8545"
    fi
    if [[ "$node_type" == "bitcoin" ]] || [[ "$node_type" == "all" ]]; then
        echo "  🔗 Bitcoin:    http://localhost:8332"
    fi
    echo ""
    print_info "Useful commands:"
    echo "  kubectl get pods -A              # Check all pods"
    echo "  kubectl logs -f <pod> -n <ns>   # View logs"
    echo "  ./scripts/check-sync.sh          # Check sync status"
    echo "  ./scripts/cleanup.sh             # Teardown everything"
    echo ""
}

main "$@"