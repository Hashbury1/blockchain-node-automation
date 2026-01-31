#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "${GREEN}$1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

install_k3d() {
    if command -v k3d >/dev/null 2>&1; then
        print_success "k3d already installed ($(k3d version | head -1))"
        return
    fi
    
    print_info "Installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    print_success "k3d installed successfully"
}

install_kubectl() {
    if command -v kubectl >/dev/null 2>&1; then
        print_success "kubectl already installed ($(kubectl version --client --short 2>/dev/null | head -1))"
        return
    fi
    
    print_info "Installing kubectl..."
    local os=$(detect_os)
    
    if [[ "$os" == "linux" ]]; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    elif [[ "$os" == "macos" ]]; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
    
    print_success "kubectl installed successfully"
}

install_helm() {
    if command -v helm >/dev/null 2>&1; then
        print_success "helm already installed ($(helm version --short))"
        return
    fi
    
    print_info "Installing helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    print_success "helm installed successfully"
}

install_ansible() {
    if command -v ansible-playbook >/dev/null 2>&1; then
        print_success "ansible already installed ($(ansible --version | head -1))"
        return
    fi
    
    print_info "Installing ansible..."
    
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install ansible --break-system-packages 2>/dev/null || pip3 install ansible --user
    elif command -v pip >/dev/null 2>&1; then
        pip install ansible --break-system-packages 2>/dev/null || pip install ansible --user
    else
        print_error "pip/pip3 not found. Please install Python3 and pip3 first."
        exit 1
    fi
    
    print_success "ansible installed successfully"
}

check_docker() {
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            print_success "Docker is installed and running"
        else
            print_error "Docker is installed but not running. Please start Docker."
            exit 1
        fi
    else
        print_error "Docker not found. Please install Docker Desktop:"
        echo "  Linux:  https://docs.docker.com/desktop/install/linux-install/"
        echo "  macOS:  https://docs.docker.com/desktop/install/mac-install/"
        echo "  Windows: https://docs.docker.com/desktop/install/windows-install/"
        exit 1
    fi
}

verify_installation() {
    print_header "\nVerifying installations..."
    
    local all_good=true
    
    for cmd in docker kubectl k3d helm ansible-playbook; do
        if command -v $cmd >/dev/null 2>&1; then
            print_success "$cmd is available"
        else
            print_error "$cmd is NOT available"
            all_good=false
        fi
    done
    
    if $all_good; then
        echo ""
        print_success "All prerequisites installed successfully!"
        echo ""
        echo "You can now deploy blockchain nodes:"
        echo "  cd $(dirname $0)/.."
        echo "  ./scripts/deploy.sh geth"
        echo ""
    else
        print_error "Some prerequisites are missing. Please install them manually."
        exit 1
    fi
}

main() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║  Blockchain Node Automation - Prerequisites   ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    print_info "Detected OS: $(detect_os)"
    echo ""
    
    check_docker
    install_kubectl
    install_k3d
    install_helm
    install_ansible
    verify_installation
}

main "$@"