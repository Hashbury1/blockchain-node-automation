# Quick Start Guide

Get your blockchain nodes running in under 10 minutes!

## Prerequisites Check

Before you begin, ensure you have:
- ✅ Docker Desktop installed and running
- ✅ 8GB+ RAM available
- ✅ 50GB+ free disk space
- ✅ Linux, macOS, or Windows with WSL2

## Installation Steps

### Step 1: Install Dependencies (5 minutes)

Run the automated setup script:

```bash
cd blockchain-node-automation
chmod +x scripts/*.sh
./scripts/setup-prerequisites.sh
```

This will install:
- k3d (Kubernetes in Docker)
- kubectl (Kubernetes CLI)
- Helm (Package manager)
- Ansible (Automation tool)

### Step 2: Deploy Your First Node (3 minutes)

#### Option A: Deploy Ethereum (Geth)
```bash
./scripts/deploy.sh geth
```

#### Option B: Deploy Bitcoin
```bash
./scripts/deploy.sh bitcoin
```

#### Option C: Deploy Both
```bash
./scripts/deploy.sh all
```

### Step 3: Access Your Services (Immediately)

Once deployment completes:

**Grafana Dashboard** 📊
```
URL: http://localhost:3000
Username: admin
Password: prom-operator
```

**Prometheus** 📈
```
URL: http://localhost:9090
```

**Geth RPC** (if deployed) 🔗
```
URL: http://localhost:8545
Test: curl http://localhost:8545 -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

**Bitcoin RPC** (if deployed) 🔗
```
URL: http://localhost:8332
Test: curl --user bitcoin:bitcoinpass123 --data-binary \
  '{"jsonrpc":"1.0","id":"test","method":"getblockchaininfo","params":[]}' \
  http://localhost:8332
```

## What Happens During Deployment?

```
1. ⏳ Creating k3d cluster...           [30 seconds]
2. ⏳ Installing monitoring stack...     [60 seconds]
3. ⏳ Deploying blockchain node(s)...    [30 seconds]
4. ⏳ Waiting for pods to be ready...    [60 seconds]
5. ✅ Deployment complete!
```

## Verify Everything is Working

### Check Pod Status
```bash
kubectl get pods -A

# Expected output:
# NAMESPACE     NAME                          READY   STATUS
# eth-nodes     geth-node-0                   2/2     Running
# btc-nodes     bitcoin-node-0                2/2     Running
# monitoring    prometheus-...                1/1     Running
# monitoring    grafana-...                   1/1     Running
```

### Check Sync Status
```bash
./scripts/check-sync.sh
```

### View Logs
```bash
# Geth logs
kubectl logs -f -n eth-nodes -l app=geth

# Bitcoin logs
kubectl logs -f -n btc-nodes -l app=bitcoin -c bitcoin
```

## Common First-Time Questions

### Q: How long does sync take?
**A:** 
- Geth (Sepolia testnet): 2-4 hours
- Bitcoin (testnet): 6-12 hours

You can use the nodes immediately, but they'll be syncing in the background.

### Q: Can I use mainnet instead of testnet?
**A:** Yes, but NOT recommended for this local setup:
- Ethereum mainnet: ~1TB+ storage needed
- Bitcoin mainnet: ~500GB+ storage needed

For this 3-day project, stick with testnets!

### Q: What if I need to restart?
**A:**
```bash
# Teardown everything
./scripts/cleanup.sh

# Redeploy
./scripts/deploy.sh geth
```

### Q: How do I stop the nodes without deleting data?
**A:**
```bash
# Scale down to 0 replicas (keeps data)
kubectl scale statefulset geth-node -n eth-nodes --replicas=0
kubectl scale statefulset bitcoin-node -n btc-nodes --replicas=0

# Scale back up
kubectl scale statefulset geth-node -n eth-nodes --replicas=1
kubectl scale statefulset bitcoin-node -n btc-nodes --replicas=1
```

### Q: Where is my blockchain data stored?
**A:** In Docker volumes managed by k3d:
```bash
# List volumes
docker volume ls | grep k3d

# Inspect a volume
docker volume inspect <volume-name>
```

## Testing Your Setup

### Test 1: Check Geth is Responding
```bash
curl http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{
    "jsonrpc":"2.0",
    "method":"eth_syncing",
    "params":[],
    "id":1
  }'
```

### Test 2: Check Bitcoin is Responding
```bash
curl --user bitcoin:bitcoinpass123 \
  --data-binary '{
    "jsonrpc":"1.0",
    "id":"test",
    "method":"getconnectioncount",
    "params":[]
  }' \
  http://localhost:8332
```

### Test 3: Check Prometheus Metrics
```bash
# Geth metrics
curl http://localhost:8545/debug/metrics/prometheus

# Bitcoin metrics  
curl http://localhost:9332/metrics
```

### Test 4: Grafana Dashboard
1. Open http://localhost:3000
2. Login with admin/prom-operator
3. Go to Dashboards → Browse
4. You should see "Geth Node Dashboard"

## Next Steps

Now that everything is running:

1. **Explore Grafana Dashboards**
   - Import community dashboards
   - Create custom visualizations
   - Set up alerts

2. **Interact with Your Nodes**
   - Use Web3.js to interact with Geth
   - Use bitcoin-cli to interact with Bitcoin
   - Build a simple DApp

3. **Customize Configuration**
   - Edit ConfigMaps in k8s/ folder
   - Adjust resource limits
   - Add more nodes

4. **Learn Kubernetes**
   - Explore kubectl commands
   - Understand pod lifecycle
   - Practice troubleshooting

## Useful Commands Cheat Sheet

```bash
# Deployment
./scripts/deploy.sh [geth|bitcoin|all]    # Deploy nodes
./scripts/cleanup.sh                       # Teardown everything
./scripts/check-sync.sh                    # Check sync status

# Kubernetes
kubectl get pods -A                        # List all pods
kubectl get svc -A                         # List all services
kubectl describe pod <name> -n <ns>        # Pod details
kubectl logs -f <pod> -n <ns>             # Stream logs
kubectl exec -it <pod> -n <ns> -- bash    # Shell into pod

# Cluster
k3d cluster list                           # List clusters
k3d cluster stop blockchain-lab            # Stop cluster
k3d cluster start blockchain-lab           # Start cluster
k3d cluster delete blockchain-lab          # Delete cluster

# Monitoring
kubectl port-forward -n monitoring \       # Forward Grafana port
  svc/prometheus-grafana 3000:80
kubectl port-forward -n monitoring \       # Forward Prometheus
  svc/prometheus-kube-prometheus-prometheus 9090:9090
```

## Troubleshooting Quick Fixes

### Issue: Pods stuck in "Pending"
```bash
kubectl describe pod <pod-name> -n <namespace>
# Usually: not enough resources or disk space
# Fix: free up disk space or adjust resource limits
```

### Issue: Ports already in use
```bash
# Find what's using the port
sudo lsof -i :8545
# Kill the process or change ports in k3d cluster create command
```

### Issue: Can't pull Docker images
```bash
# Check Docker is running
docker ps
# Check internet connection
docker pull hello-world
```

### Issue: Deployment fails with timeout
```bash
# Check cluster is healthy
kubectl get nodes
# Check system resources
docker stats
# Increase timeout in Ansible playbook
```

## Getting Help

- **Check logs**: `./scripts/check-sync.sh`
- **View events**: `kubectl get events -A --sort-by='.lastTimestamp'`
- **Architecture docs**: `docs/architecture.md`
- **GitHub Issues**: (create an issue on your repo)

## Success Checklist

After completing this guide, you should have:

- [ ] k3d cluster running
- [ ] Geth and/or Bitcoin nodes deployed
- [ ] Prometheus collecting metrics
- [ ] Grafana showing dashboards
- [ ] Ability to query nodes via RPC
- [ ] Understanding of basic kubectl commands
- [ ] Logs accessible for debugging

Congratulations! You now have a fully functional blockchain node infrastructure. 
