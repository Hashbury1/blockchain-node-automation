# Architecture Documentation

## Overview

This project provides a complete, automated infrastructure for running Ethereum and Bitcoin nodes locally using Kubernetes (k3d), with full observability through Prometheus and Grafana.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Local Machine                             │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              k3d Kubernetes Cluster                         │ │
│  │                                                              │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │ │
│  │  │  eth-nodes   │  │  btc-nodes   │  │   monitoring    │  │ │
│  │  │  namespace   │  │  namespace   │  │   namespace     │  │ │
│  │  │              │  │              │  │                 │  │ │
│  │  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌──────────┐  │  │ │
│  │  │  │ Geth   │  │  │  │Bitcoin │  │  │  │Prometheus│  │  │ │
│  │  │  │ Node   │  │  │  │  Core  │  │  │  └─────┬────┘  │  │ │
│  │  │  │        │  │  │  │        │  │  │        │       │  │ │
│  │  │  │ :8545  │  │  │  │ :18332 │  │  │  ┌─────▼────┐  │  │ │
│  │  │  │ :6060──┼──┼──┼──┼────────┼──┼──┼─▶│ Scrapes  │  │  │ │
│  │  │  └────────┘  │  │  │        │  │  │  │ Metrics  │  │  │ │
│  │  │              │  │  │ :9332──┼──┼──┼─▶│          │  │  │ │
│  │  │  ┌────────┐  │  │  └────────┘  │  │  └──────────┘  │  │ │
│  │  │  │ Fluent │  │  │              │  │                 │  │ │
│  │  │  │  Bit   │  │  │  ┌────────┐  │  │  ┌──────────┐  │  │ │
│  │  │  └────────┘  │  │  │  BTC   │  │  │  │ Grafana  │  │  │ │
│  │  │              │  │  │Exporter│  │  │  │          │  │  │ │
│  │  └──────────────┘  │  └────────┘  │  │  │ :3000    │  │  │ │
│  │                    └──────────────┘  │  └──────────┘  │  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Port Forwarding                          │ │
│  │                                                              │ │
│  │   localhost:8545  ──▶  Geth RPC                            │ │
│  │   localhost:8332  ──▶  Bitcoin RPC                         │ │
│  │   localhost:3000  ──▶  Grafana Dashboard                   │ │
│  │   localhost:9090  ──▶  Prometheus                          │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Kubernetes Cluster (k3d)
- **Purpose**: Lightweight Kubernetes distribution for local development
- **Configuration**: 1 server + 2 agents
- **Storage**: local-path provisioner (uses host filesystem)
- **Networking**: Traefik ingress + NodePort services

### 2. Ethereum Node (Geth)
- **Image**: `ethereum/client-go:latest`
- **Network**: Sepolia testnet
- **Sync Mode**: Snap (fast sync)
- **Ports**:
  - 8545: HTTP RPC
  - 8546: WebSocket RPC
  - 6060: Metrics endpoint
  - 30303: P2P
- **Storage**: 30Gi PVC
- **Resources**: 4-6Gi RAM, 1-2 CPU cores

### 3. Bitcoin Node
- **Image**: `ruimarinho/bitcoin-core:latest`
- **Network**: Testnet
- **Ports**:
  - 18332: RPC
  - 18333: P2P
  - 9332: Metrics (via exporter)
- **Storage**: 50Gi PVC
- **Resources**: 2-4Gi RAM, 0.5-1.5 CPU cores

### 4. Monitoring Stack
- **Prometheus**: Time-series database for metrics
- **Grafana**: Visualization and dashboarding
- **ServiceMonitors**: Auto-discovery of metrics endpoints
- **Exporters**: Bitcoin metrics exporter

### 5. Log Aggregation
- **Fluent Bit**: Lightweight log forwarder
- **Configuration**: Ships logs to stdout (extensible to ELK, Loki, etc.)

## Data Flow

### Metrics Flow
1. Geth exposes metrics on port 6060
2. Bitcoin exporter scrapes Bitcoin RPC and exposes on port 9332
3. Prometheus scrapes both endpoints every 30s
4. Grafana queries Prometheus for visualization

### Log Flow
1. Application logs → stdout/stderr
2. Kubernetes captures to `/var/log/containers`
3. Fluent Bit tails log files
4. Logs forwarded to stdout (can be extended)

### Health Checks
1. **Liveness Probe**: Ensures pod is alive, restarts if fails
2. **Readiness Probe**: Ensures pod can accept traffic
3. **Restart Policy**: Always (auto-restart on failure)

## Deployment Workflow

```
User runs deploy.sh
       │
       ▼
Check prerequisites
       │
       ▼
Create k3d cluster
       │
       ▼
Deploy monitoring stack (Helm)
       │
       ▼
Apply Kubernetes manifests
   ┌───┴───┐
   │       │
   ▼       ▼
 Geth   Bitcoin
   │       │
   └───┬───┘
       │
       ▼
Wait for pods ready
       │
       ▼
Display access info
```

## Automation Stack

### Bash Scripts
- `deploy.sh`: Main orchestration
- `check-sync.sh`: Status monitoring
- `cleanup.sh`: Teardown
- `setup-prerequisites.sh`: Install dependencies

### Ansible
- **Playbook**: `deploy-nodes.yml`
- **Idempotent**: Can run multiple times safely
- **Variables**: Node type, monitoring toggle
- **Tasks**: Cluster creation, Helm deployments, kubectl applies

### Kubernetes Manifests
- **Declarative**: YAML files for all resources
- **Namespaced**: Isolation between components
- **Labels**: For organization and selection
- **ConfigMaps**: Externalized configuration

## Scalability Considerations

### Current Setup (Local)
- Single node of each type
- Local storage (no replication)
- Suitable for: Development, testing, demos

### Production Considerations
Would need:
- **HA Setup**: Multiple replicas with LoadBalancer
- **Persistent Storage**: Cloud volumes (EBS, GCE PD)
- **Ingress**: TLS, authentication, rate limiting
- **Backup**: Regular snapshots of blockchain data
- **Resource Limits**: Proper sizing based on workload
- **Network Policies**: Restrict inter-pod communication
- **Secrets Management**: Vault or sealed secrets
- **CI/CD**: GitOps with ArgoCD or Flux

## Security Notes

⚠️ **This setup is for LOCAL development only**

### Current Security Posture
- No authentication on RPC endpoints
- No TLS/encryption
- Runs as root in containers
- Open CORS policies
- No network segmentation

### For Production
Would implement:
- JWT/API key authentication
- TLS everywhere
- Non-root containers with security contexts
- Network policies
- Secret management
- Regular security scanning
- Audit logging

## Cost Analysis

| Component | Cloud Cost | Local Cost |
|-----------|-----------|------------|
| Kubernetes | $70+/month (EKS) | $0 (k3d) |
| Compute | $100+/month | $0 (laptop) |
| Storage | $30+/month | $0 (disk) |
| Monitoring | $50+/month | $0 (OSS) |
| **Total** | **$250+/month** | **$0** |

This architecture saves ~$3000/year by running locally!

## Performance Metrics

### Sync Times (Approximate)
- **Geth (Sepolia)**: 2-4 hours to sync
- **Bitcoin (Testnet)**: 6-12 hours initial sync

### Resource Usage
- **CPU**: 20-40% average (2 cores allocated)
- **Memory**: 6-8Gi total
- **Disk**: 80-100Gi total after sync
- **Network**: 1-5 Mbps average

## Troubleshooting

### Common Issues

**Pods stuck in Pending**
```bash
kubectl describe pod <pod-name> -n <namespace>
# Usually disk space or resource limits
```

**Can't access services**
```bash
kubectl get svc -A
# Check NodePort mappings
```

**Sync not progressing**
```bash
./scripts/check-sync.sh
# Check peer count and logs
```

### Log Investigation
```bash
# Geth logs
kubectl logs -f statefulset/geth-node -n eth-nodes

# Bitcoin logs
kubectl logs -f statefulset/bitcoin-node -n btc-nodes -c bitcoin

# All events
kubectl get events -A --sort-by='.lastTimestamp'
```

## Future Enhancements

- [ ] Add more blockchain nodes (Polygon, Avalanche)
- [ ] Implement backup/restore functionality
- [ ] Add alerting rules (AlertManager)
- [ ] Create more Grafana dashboards
- [ ] Add network traffic visualization
- [ ] Implement blue-green deployments
- [ ] Add load testing scripts
- [ ] Create Terraform module for cloud deployment
- [ ] Add automatic node version updates