# 1. Check if cluster exists
echo "=== Checking Cluster ==="
k3d cluster list

# 2. Check if you can connect to cluster
echo -e "\n=== Checking Connection ==="
kubectl get nodes

# 3. Check all namespaces
echo -e "\n=== Checking Namespaces ==="
kubectl get namespaces

# 4. Check ALL pods
echo -e "\n=== Checking All Pods ==="
kubectl get pods -A

# 5. Check if eth-nodes namespace exists
echo -e "\n=== Checking eth-nodes specifically ==="
kubectl get all -n eth-nodes 2>/dev/null || echo "Namespace eth-nodes does not exist"

# 6. Check recent events
echo -e "\n=== Recent Events ==="
kubectl get events -A --sort-by='.lastTimestamp' | tail -10
```

## 📊 What to Look For

Based on the output, you'll see one of these scenarios:

### **Scenario 1: No cluster exists**
```
No clusters found