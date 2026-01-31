#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

confirm_cleanup() {
    echo -e "${RED}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║        WARNING: DESTRUCTIVE OPERATION              ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "This will:"
    echo "  • Delete the k3d cluster 'blockchain-lab'"
    echo "  • Remove all blockchain data"
    echo "  • Delete all monitoring data"
    echo "  • Stop all running containers"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
}

cleanup_kubernetes() {
    print_warning "Cleaning up Kubernetes resources..."
    
    # Delete namespaces (this will cascade delete all resources)
    kubectl delete namespace eth-nodes --ignore-not-found=true 2>/dev/null || true
    kubectl delete namespace btc-nodes --ignore-not-found=true 2>/dev/null || true
    
    # Uninstall monitoring stack
    helm uninstall prometheus -n monitoring 2>/dev/null || true
    kubectl delete namespace monitoring --ignore-not-found=true 2>/dev/null || true
    
    print_success "Kubernetes resources cleaned up"
}

delete_cluster() {
    print_warning "Deleting k3d cluster..."
    
    if k3d cluster list | grep -q blockchain-lab; then
        k3d cluster delete blockchain-lab
        print_success "Cluster deleted successfully"
    else
        print_warning "Cluster 'blockchain-lab' not found"
    fi
}

cleanup_docker_resources() {
    print_warning "Cleaning up unused Docker resources..."
    
    # Remove dangling images and volumes
    docker system prune -f 2>/dev/null || true
    
    print_success "Docker cleanup complete"
}

main() {
    echo -e "${YELLOW}"
    echo "╔════════════════════════════════════════╗"
    echo "║   Blockchain Node Cleanup Script      ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Check if cluster exists
    if ! k3d cluster list 2>/dev/null | grep -q blockchain-lab; then
        print_warning "No cluster found. Nothing to clean up."
        exit 0
    fi
    
    confirm_cleanup
    
    cleanup_kubernetes
    delete_cluster
    cleanup_docker_resources
    
    echo ""
    print_success "Cleanup completed successfully!"
    echo ""
    echo "To redeploy, run:"
    echo "  ./scripts/deploy.sh [geth|bitcoin|all]"
    echo ""
}

main "$@"