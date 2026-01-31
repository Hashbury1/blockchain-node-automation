#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_section() {
    echo -e "\n${GREEN}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}\n"
}

check_geth_sync() {
    print_section "Geth Sync Status"
    
    if kubectl get pods -n eth-nodes -l app=geth 2>/dev/null | grep -q Running; then
        echo -e "${GREEN}✓ Geth pod is running${NC}"
        
        POD_NAME=$(kubectl get pods -n eth-nodes -l app=geth -o jsonpath='{.items[0].metadata.name}')
        
        echo ""
        echo "Fetching sync status..."
        kubectl exec -n eth-nodes "$POD_NAME" -- geth attach --exec "eth.syncing" 2>/dev/null || echo "Unable to connect to Geth RPC"
        
        echo ""
        echo "Current block:"
        kubectl exec -n eth-nodes "$POD_NAME" -- geth attach --exec "eth.blockNumber" 2>/dev/null || echo "Unable to fetch block number"
        
        echo ""
        echo "Peer count:"
        kubectl exec -n eth-nodes "$POD_NAME" -- geth attach --exec "net.peerCount" 2>/dev/null || echo "Unable to fetch peer count"
    else
        echo -e "${RED}✗ Geth pod is not running${NC}"
    fi
}

check_bitcoin_sync() {
    print_section "Bitcoin Sync Status"
    
    if kubectl get pods -n btc-nodes -l app=bitcoin 2>/dev/null | grep -q Running; then
        echo -e "${GREEN}✓ Bitcoin pod is running${NC}"
        
        POD_NAME=$(kubectl get pods -n btc-nodes -l app=bitcoin -o jsonpath='{.items[0].metadata.name}')
        
        echo ""
        echo "Fetching blockchain info..."
        kubectl exec -n btc-nodes "$POD_NAME" -c bitcoin -- \
            bitcoin-cli -testnet -rpcuser=bitcoin -rpcpassword=bitcoinpass123 getblockchaininfo 2>/dev/null || \
            echo "Unable to connect to Bitcoin RPC"
        
        echo ""
        echo "Connection count:"
        kubectl exec -n btc-nodes "$POD_NAME" -c bitcoin -- \
            bitcoin-cli -testnet -rpcuser=bitcoin -rpcpassword=bitcoinpass123 getconnectioncount 2>/dev/null || \
            echo "Unable to fetch connection count"
    else
        echo -e "${RED}✗ Bitcoin pod is not running${NC}"
    fi
}

check_monitoring() {
    print_section "Monitoring Stack Status"
    
    echo "Prometheus:"
    kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus 2>/dev/null | tail -n +2 || echo "Not deployed"
    
    echo ""
    echo "Grafana:"
    kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana 2>/dev/null | tail -n +2 || echo "Not deployed"
}

main() {
    echo -e "${YELLOW}"
    echo "╔════════════════════════════════════════╗"
    echo "║   Blockchain Node Status Checker      ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_geth_sync
    check_bitcoin_sync
    check_monitoring
    
    echo ""
    echo -e "${GREEN}Status check complete!${NC}"
    echo ""
    echo "For real-time logs:"
    echo "  Geth:    kubectl logs -f -n eth-nodes -l app=geth"
    echo "  Bitcoin: kubectl logs -f -n btc-nodes -l app=bitcoin"
    echo ""
}

main "$@"