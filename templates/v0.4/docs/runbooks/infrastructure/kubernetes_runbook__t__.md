# Kubernetes Runbook

## Overview
Operational procedures for deploying and managing applications on Kubernetes (self-managed or managed services like EKS, GKE, AKS).

## Prerequisites
- Kubernetes cluster (local: minikube/kind, managed: EKS/GKE/AKS)
- `kubectl` installed: `brew install kubectl` (macOS) or https://kubernetes.io/docs/tasks/tools/
- `kubeconfig` configured: `kubectl config view`
- Container registry access (Docker Hub, ECR, GCR, etc.)
- Optional: Helm for package management

---

## Setup

### Initial Provisioning

1. **Create namespace:**
   ```bash
   kubectl create namespace my-app
   kubectl config set-context --current --namespace=my-app
   ```

2. **Create container registry secret (if using private registry):**
   ```bash
   kubectl create secret docker-registry regcred \
     --docker-server=<registry-url> \
     --docker-username=<username> \
     --docker-password=<password> \
     --docker-email=<email> \
     -n my-app
   ```

3. **Create ConfigMap for non-sensitive config:**
   ```bash
   kubectl create configmap my-app-config \
     --from-literal=PORT=8080 \
     --from-literal=LOG_LEVEL=info \
     -n my-app
   ```

4. **Create Secret for sensitive data:**
   ```bash
   kubectl create secret generic my-app-secrets \
     --from-literal=DATABASE_URL=postgres://... \
     --from-literal=API_KEY=secret-value \
     -n my-app
   ```

5. **Create Deployment manifest (`deployment.yaml`):**
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: my-app
     namespace: my-app
     labels:
       app: my-app
   spec:
     replicas: 3
     selector:
       matchLabels:
         app: my-app
     template:
       metadata:
         labels:
           app: my-app
       spec:
         containers:
         - name: my-app
           image: registry.example.com/my-app:latest
           ports:
           - containerPort: 8080
           env:
           - name: PORT
             valueFrom:
               configMapKeyRef:
                 name: my-app-config
                 key: PORT
           - name: DATABASE_URL
             valueFrom:
               secretKeyRef:
                 name: my-app-secrets
                 key: DATABASE_URL
           resources:
             requests:
               memory: "128Mi"
               cpu: "100m"
             limits:
               memory: "256Mi"
               cpu: "500m"
           livenessProbe:
             httpGet:
               path: /health/live
               port: 8080
             initialDelaySeconds: 30
             periodSeconds: 10
           readinessProbe:
             httpGet:
               path: /health/ready
               port: 8080
             initialDelaySeconds: 5
             periodSeconds: 5
         imagePullSecrets:
         - name: regcred
   ```

6. **Create Service manifest (`service.yaml`):**
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: my-app
     namespace: my-app
   spec:
     selector:
       app: my-app
     ports:
     - protocol: TCP
       port: 80
       targetPort: 8080
     type: LoadBalancer  # or ClusterIP, NodePort
   ```

7. **Create Ingress (optional, for HTTP routing):**
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: my-app
     namespace: my-app
     annotations:
       cert-manager.io/cluster-issuer: letsencrypt-prod
   spec:
     ingressClassName: nginx
     tls:
     - hosts:
       - my-app.example.com
       secretName: my-app-tls
     rules:
     - host: my-app.example.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: my-app
               port:
                 number: 80
   ```

8. **Apply manifests:**
   ```bash
   kubectl apply -f deployment.yaml
   kubectl apply -f service.yaml
   kubectl apply -f ingress.yaml
   ```

---

## Deploy

### Standard Deployment

1. **Build and push new image:**
   ```bash
   # Build with Docker or Podman
   docker build -t my-app:v2 .
   docker tag my-app:v2 registry.example.com/my-app:v2
   docker push registry.example.com/my-app:v2
   ```

2. **Update deployment with new image:**
   ```bash
   kubectl set image deployment/my-app my-app=registry.example.com/my-app:v2 -n my-app
   ```

3. **Monitor rollout:**
   ```bash
   kubectl rollout status deployment/my-app -n my-app
   kubectl get pods -n my-app -w
   ```

### Declarative Deployment

```bash
# Update deployment.yaml with new image tag
# Then apply:
kubectl apply -f deployment.yaml

# Verify
kubectl rollout status deployment/my-app -n my-app
```

### Deployment Strategies

#### Rolling Update (default)
```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # max pods above desired count
      maxUnavailable: 0  # max pods unavailable during update
```

#### Recreate (downtime)
```yaml
spec:
  strategy:
    type: Recreate
```

#### Blue-Green (manual)
```bash
# Deploy new version with different label
kubectl apply -f deployment-green.yaml

# Test green deployment
kubectl port-forward deployment/my-app-green 8080:8080

# Switch service to green
kubectl patch service my-app -p '{"spec":{"selector":{"version":"green"}}}'

# Delete blue deployment
kubectl delete deployment my-app-blue
```

#### Canary (using Argo Rollouts or manual)
```bash
# Deploy canary with 10% traffic
kubectl apply -f deployment-canary.yaml
kubectl scale deployment my-app-canary --replicas=1

# Monitor metrics, then scale up canary
kubectl scale deployment my-app-canary --replicas=3
kubectl scale deployment my-app --replicas=0
```

---

## Scale

### Manual Scaling

```bash
# Scale replicas
kubectl scale deployment my-app --replicas=5 -n my-app

# Verify
kubectl get deployment my-app -n my-app
kubectl get pods -n my-app
```

### Horizontal Pod Autoscaler (HPA)

```bash
# Create HPA based on CPU
kubectl autoscale deployment my-app --cpu-percent=70 --min=2 --max=10 -n my-app

# Or use manifest:
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
  namespace: my-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

# Check HPA status
kubectl get hpa -n my-app
kubectl describe hpa my-app-hpa -n my-app
```

### Vertical Pod Autoscaler (VPA)

```bash
# Install VPA (if not already installed)
# https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler

# Create VPA
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
  namespace: my-app
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Auto"  # or "Recreate", "Initial", "Off"
EOF

# Check VPA recommendations
kubectl describe vpa my-app-vpa -n my-app
```

---

## Monitor

### Logs

```bash
# View logs from all pods
kubectl logs -l app=my-app -n my-app

# Follow logs
kubectl logs -l app=my-app -n my-app -f

# Logs from specific pod
kubectl logs <pod-name> -n my-app

# Logs from specific container (if multiple containers)
kubectl logs <pod-name> -c my-app -n my-app

# Previous container logs (if crashed)
kubectl logs <pod-name> -n my-app --previous
```

### Metrics

```bash
# Install metrics-server (if not already installed)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# View node metrics
kubectl top nodes

# View pod metrics
kubectl top pods -n my-app

# View pod metrics with containers
kubectl top pods -n my-app --containers
```

### Events

```bash
# View events in namespace
kubectl get events -n my-app --sort-by='.lastTimestamp'

# Watch events
kubectl get events -n my-app -w

# Filter events by type
kubectl get events -n my-app --field-selector type=Warning
```

### Dashboard

```bash
# Install Kubernetes Dashboard (optional)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin user and get token
kubectl create serviceaccount admin-user -n kubernetes-dashboard
kubectl create clusterrolebinding admin-user --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:admin-user
kubectl -n kubernetes-dashboard create token admin-user

# Access dashboard
kubectl proxy
# Open: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### Prometheus & Grafana (recommended)

```bash
# Install with Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open: http://localhost:3000 (default: admin/prom-operator)
```

---

## Debug

### Common Issues

#### Pods not starting
```bash
# Check pod status
kubectl get pods -n my-app
kubectl describe pod <pod-name> -n my-app

# Common causes:
# - ImagePullBackOff: wrong image name, missing registry credentials
# - CrashLoopBackOff: app crashes on startup, check logs
# - Pending: insufficient resources, check node capacity
# - CreateContainerConfigError: missing ConfigMap/Secret

# Check logs
kubectl logs <pod-name> -n my-app

# Check events
kubectl get events -n my-app --field-selector involvedObject.name=<pod-name>
```

#### Service not reachable
```bash
# Check service
kubectl get svc my-app -n my-app
kubectl describe svc my-app -n my-app

# Check endpoints (should list pod IPs)
kubectl get endpoints my-app -n my-app

# Test service from within cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Inside pod:
apk add curl
curl http://my-app.my-app.svc.cluster.local

# Check ingress
kubectl get ingress -n my-app
kubectl describe ingress my-app -n my-app
```

#### High resource usage
```bash
# Check resource usage
kubectl top pods -n my-app

# Check resource limits
kubectl describe pod <pod-name> -n my-app | grep -A 5 "Limits"

# Increase resources in deployment
kubectl set resources deployment my-app --limits=cpu=1,memory=512Mi --requests=cpu=500m,memory=256Mi -n my-app
```

### Interactive Debugging

```bash
# Exec into running pod
kubectl exec -it <pod-name> -n my-app -- /bin/sh

# Run debug container in pod's namespace (Kubernetes 1.23+)
kubectl debug <pod-name> -n my-app -it --image=alpine

# Create ephemeral debug container (Kubernetes 1.23+)
kubectl debug <pod-name> -n my-app -it --image=alpine --target=my-app

# Port forward for local testing
kubectl port-forward <pod-name> 8080:8080 -n my-app
```

---

## Rollback

### Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/my-app -n my-app

# Rollback to previous version
kubectl rollout undo deployment/my-app -n my-app

# Rollback to specific revision
kubectl rollout undo deployment/my-app --to-revision=2 -n my-app

# Verify rollback
kubectl rollout status deployment/my-app -n my-app
```

### Pause/Resume Rollout

```bash
# Pause rollout (for troubleshooting)
kubectl rollout pause deployment/my-app -n my-app

# Resume rollout
kubectl rollout resume deployment/my-app -n my-app
```

---

## Secrets

### Manage Secrets

```bash
# Create secret from literals
kubectl create secret generic my-secret --from-literal=key1=value1 --from-literal=key2=value2 -n my-app

# Create secret from file
kubectl create secret generic my-secret --from-file=./secrets.env -n my-app

# View secret (base64 encoded)
kubectl get secret my-secret -n my-app -o yaml

# Decode secret
kubectl get secret my-secret -n my-app -o jsonpath='{.data.key1}' | base64 -d

# Update secret
kubectl create secret generic my-secret --from-literal=key1=new-value --dry-run=client -o yaml | kubectl apply -f -

# Delete secret
kubectl delete secret my-secret -n my-app
```

### Rotate Secrets

```bash
# Update secret
kubectl create secret generic my-app-secrets --from-literal=API_KEY=new-key --dry-run=client -o yaml | kubectl apply -f -

# Force pod restart to pick up new secret
kubectl rollout restart deployment/my-app -n my-app
```

### External Secrets Operator (recommended for production)

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# Create SecretStore (e.g., AWS Secrets Manager)
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: my-app
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: my-app-sa
EOF

# Create ExternalSecret
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: my-app-secrets
  data:
  - secretKey: DATABASE_URL
    remoteRef:
      key: my-app/database-url
EOF
```

---

## Backup and Disaster Recovery

### Backup with Velero

```bash
# Install Velero
velero install --provider aws --bucket my-backups --secret-file ./credentials-velero --backup-location-config region=us-east-1

# Create backup
velero backup create my-app-backup --include-namespaces my-app

# Schedule regular backups
velero schedule create my-app-daily --schedule="0 2 * * *" --include-namespaces my-app

# List backups
velero backup get

# Restore from backup
velero restore create --from-backup my-app-backup
```

### Disaster Recovery Strategy

- **etcd backups:** Regular snapshots of cluster state (managed by cloud provider or manual)
- **Persistent volume snapshots:** Use CSI snapshots or cloud provider tools
- **GitOps:** Store all manifests in Git (Flux, ArgoCD)
- **Multi-cluster:** Deploy to multiple clusters for high availability

---

## Destroy

### Remove Application

```bash
# Delete deployment
kubectl delete deployment my-app -n my-app

# Delete service
kubectl delete service my-app -n my-app

# Delete ingress
kubectl delete ingress my-app -n my-app

# Delete ConfigMaps and Secrets
kubectl delete configmap my-app-config -n my-app
kubectl delete secret my-app-secrets -n my-app

# Delete namespace (removes all resources)
kubectl delete namespace my-app
```

### Clean Up Cluster Resources

```bash
# Delete unused PVCs
kubectl get pvc -A
kubectl delete pvc <pvc-name> -n <namespace>

# Delete completed jobs
kubectl delete jobs --field-selector status.successful=1 -A

# Delete evicted pods
kubectl get pods -A --field-selector status.phase=Failed -o json | kubectl delete -f -
```

---

## Cost Optimization

### Tips

- **Right-size pods:** Use VPA recommendations, avoid over-provisioning
- **Use node autoscaling:** Scale nodes based on demand (cluster autoscaler)
- **Use spot/preemptible nodes:** 70-90% discount for fault-tolerant workloads
- **Set resource requests/limits:** Prevent resource waste and noisy neighbors
- **Use PodDisruptionBudgets:** Safely drain nodes during scaling
- **Monitor unused resources:** Delete orphaned PVCs, LoadBalancers, unused namespaces
- **Use Horizontal Pod Autoscaling:** Scale pods based on actual load

### Managed Kubernetes Pricing

- **EKS:** $0.10/hour per cluster + EC2/Fargate costs
- **GKE:** $0.10/hour per cluster (free for Autopilot) + GCE costs
- **AKS:** Free control plane + VM costs

---

## References

- **Kubernetes Documentation:** https://kubernetes.io/docs/
- **kubectl Cheat Sheet:** https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **Helm Documentation:** https://helm.sh/docs/
- **Kubernetes Patterns:** https://www.redhat.com/en/resources/oreilly-kubernetes-patterns-ebook
- **Production Best Practices:** https://learnk8s.io/production-best-practices
