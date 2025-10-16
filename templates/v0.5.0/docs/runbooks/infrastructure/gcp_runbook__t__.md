# GCP (Google Cloud Platform) Runbook

## Overview
Operational procedures for deploying and managing applications on Google Cloud Platform. This runbook covers **Cloud Run** (serverless containers) and **GKE** (Google Kubernetes Engine). For pure Kubernetes operations, see [kubernetes_runbook.md](kubernetes_runbook.md).

## Prerequisites
- GCP account: https://cloud.google.com/
- `gcloud` CLI installed: `brew install google-cloud-sdk` (macOS) or https://cloud.google.com/sdk/docs/install
- Authenticated: `gcloud auth login`
- Project selected: `gcloud config set project <project-id>`
- Billing enabled on project

---

## Setup

### Initial Configuration

```bash
# Set default project
gcloud config set project my-project-id

# Set default region
gcloud config set run/region us-central1

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

---

## Cloud Run Setup

Cloud Run is ideal for stateless HTTP services with automatic scaling to zero.

### 1. Create Artifact Registry Repository

```bash
# Create repository for container images
gcloud artifacts repositories create my-app \
  --repository-format=docker \
  --location=us-central1 \
  --description="My application images"

# Configure Docker/Podman authentication
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### 2. Build and Push Container Image

```bash
# Build with Docker or Podman
docker build -t my-app:latest .

# Tag for Artifact Registry
docker tag my-app:latest us-central1-docker.pkg.dev/my-project-id/my-app/my-app:latest

# Push image
docker push us-central1-docker.pkg.dev/my-project-id/my-app/my-app:latest

# Or use Cloud Build (builds in GCP)
gcloud builds submit --tag us-central1-docker.pkg.dev/my-project-id/my-app/my-app:latest
```

### 3. Deploy to Cloud Run

```bash
# Deploy service
gcloud run deploy my-app \
  --image us-central1-docker.pkg.dev/my-project-id/my-app/my-app:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8080 \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10 \
  --concurrency 80 \
  --timeout 300s

# Get service URL
gcloud run services describe my-app --region us-central1 --format 'value(status.url)'
```

### 4. Configure Environment Variables and Secrets

```bash
# Set environment variables
gcloud run services update my-app \
  --region us-central1 \
  --set-env-vars "PORT=8080,LOG_LEVEL=info"

# Create secret in Secret Manager
gcloud secrets create database-url --data-file=-
# Paste secret value, then Ctrl+D

# Grant Cloud Run service account access to secret
gcloud secrets add-iam-policy-binding database-url \
  --member="serviceAccount:$(gcloud run services describe my-app --region us-central1 --format='value(spec.template.spec.serviceAccountName)')" \
  --role="roles/secretmanager.secretAccessor"

# Mount secret as environment variable
gcloud run services update my-app \
  --region us-central1 \
  --set-secrets "DATABASE_URL=database-url:latest"
```

### 5. Configure Custom Domain (Optional)

```bash
# Map custom domain
gcloud run domain-mappings create --service my-app --domain my-app.example.com --region us-central1

# Follow instructions to update DNS records
gcloud run domain-mappings describe --domain my-app.example.com --region us-central1
```

---

## GKE Setup

For more complex applications requiring Kubernetes features.

### 1. Create GKE Cluster

```bash
# Create autopilot cluster (managed, recommended)
gcloud container clusters create-auto my-cluster \
  --region us-central1

# Or create standard cluster (more control)
gcloud container clusters create my-cluster \
  --region us-central1 \
  --num-nodes 3 \
  --machine-type e2-medium \
  --disk-size 50 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 10 \
  --enable-autorepair \
  --enable-autoupgrade

# Get cluster credentials
gcloud container clusters get-credentials my-cluster --region us-central1
```

### 2. Deploy to GKE

See [kubernetes_runbook.md](kubernetes_runbook.md) for detailed Kubernetes operations. Quick example:

```bash
# Create namespace
kubectl create namespace my-app

# Deploy application
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-app
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
        image: us-central1-docker.pkg.dev/my-project-id/my-app/my-app:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: my-app
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
EOF

# Get external IP
kubectl get service my-app -n my-app
```

---

## Deploy

### Cloud Run Deployment

```bash
# Deploy new version
gcloud run deploy my-app \
  --image us-central1-docker.pkg.dev/my-project-id/my-app/my-app:v2 \
  --region us-central1

# Deploy with traffic split (canary)
gcloud run deploy my-app \
  --image us-central1-docker.pkg.dev/my-project-id/my-app/my-app:v2 \
  --region us-central1 \
  --no-traffic \
  --tag canary

# Route 10% traffic to canary
gcloud run services update-traffic my-app \
  --region us-central1 \
  --to-revisions canary=10,LATEST=90

# Monitor, then shift all traffic
gcloud run services update-traffic my-app \
  --region us-central1 \
  --to-latest
```

### GKE Deployment

```bash
# Build and push new image
gcloud builds submit --tag us-central1-docker.pkg.dev/my-project-id/my-app/my-app:v2

# Update deployment
kubectl set image deployment/my-app my-app=us-central1-docker.pkg.dev/my-project-id/my-app/my-app:v2 -n my-app

# Monitor rollout
kubectl rollout status deployment/my-app -n my-app
```

### CI/CD with Cloud Build

Create `cloudbuild.yaml`:

```yaml
steps:
  # Build container image
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'us-central1-docker.pkg.dev/$PROJECT_ID/my-app/my-app:$SHORT_SHA', '.']
  
  # Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'us-central1-docker.pkg.dev/$PROJECT_ID/my-app/my-app:$SHORT_SHA']
  
  # Deploy to Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - 'my-app'
      - '--image=us-central1-docker.pkg.dev/$PROJECT_ID/my-app/my-app:$SHORT_SHA'
      - '--region=us-central1'
      - '--platform=managed'

images:
  - 'us-central1-docker.pkg.dev/$PROJECT_ID/my-app/my-app:$SHORT_SHA'

options:
  logging: CLOUD_LOGGING_ONLY
```

Trigger build:

```bash
# Manual trigger
gcloud builds submit --config cloudbuild.yaml

# Create trigger from GitHub
gcloud builds triggers create github \
  --repo-name=my-repo \
  --repo-owner=my-org \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

---

## Scale

### Cloud Run Scaling

```bash
# Update scaling settings
gcloud run services update my-app \
  --region us-central1 \
  --min-instances 1 \
  --max-instances 100 \
  --concurrency 80

# Scale to zero when idle (default)
gcloud run services update my-app \
  --region us-central1 \
  --min-instances 0

# Update CPU and memory
gcloud run services update my-app \
  --region us-central1 \
  --memory 1Gi \
  --cpu 2
```

### GKE Scaling

```bash
# Manual scaling
kubectl scale deployment my-app --replicas=5 -n my-app

# Horizontal Pod Autoscaler
kubectl autoscale deployment my-app \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n my-app

# Cluster autoscaling (if not using Autopilot)
gcloud container clusters update my-cluster \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 10 \
  --region us-central1
```

---

## Monitor

### Cloud Run Monitoring

```bash
# View logs
gcloud run services logs read my-app --region us-central1 --limit 50

# Tail logs
gcloud run services logs tail my-app --region us-central1

# Filter logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=my-app AND severity>=ERROR" --limit 50 --format json
```

### Cloud Logging

```bash
# View logs from all services
gcloud logging read "resource.type=cloud_run_revision" --limit 100

# Create log-based metric
gcloud logging metrics create error_count \
  --description="Count of error logs" \
  --log-filter='resource.type="cloud_run_revision" AND severity>=ERROR'
```

### Cloud Monitoring (Stackdriver)

Access via Console: https://console.cloud.google.com/monitoring

**Key Metrics:**
- **Cloud Run:** Request count, latency, container CPU/memory utilization, billable instance time
- **GKE:** Node CPU/memory, pod CPU/memory, container restarts

**Create Alert:**

```bash
# Create alert policy via gcloud (or use Console)
gcloud alpha monitoring policies create \
  --notification-channels=<channel-id> \
  --display-name="High Error Rate" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=5 \
  --condition-threshold-duration=300s
```

### Cloud Trace (Distributed Tracing)

Enable in application using OpenTelemetry or Cloud Trace SDK:

```bash
# View traces in Console
gcloud trace list --limit 10
```

### Dashboards

Create custom dashboards in Cloud Monitoring Console:
- Request rate and latency
- Error rate by HTTP status
- Container CPU and memory usage
- Cold start frequency (Cloud Run)

---

## Debug

### Cloud Run Debugging

```bash
# Check service status
gcloud run services describe my-app --region us-central1

# View recent revisions
gcloud run revisions list --service my-app --region us-central1

# View logs with errors
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=my-app AND severity>=ERROR" --limit 50

# Test service locally
docker run -p 8080:8080 -e PORT=8080 us-central1-docker.pkg.dev/my-project-id/my-app/my-app:latest
curl http://localhost:8080/health
```

### Common Cloud Run Issues

#### Cold starts
```bash
# Set minimum instances to avoid cold starts
gcloud run services update my-app --region us-central1 --min-instances 1

# Optimize container: use Alpine Linux, minimize dependencies, use distroless images
```

#### Timeout errors
```bash
# Increase timeout (max 3600s for HTTP, 60s for events)
gcloud run services update my-app --region us-central1 --timeout 600s
```

#### Memory errors
```bash
# Increase memory
gcloud run services update my-app --region us-central1 --memory 1Gi

# Check memory usage in logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=my-app AND textPayload=~\"memory\"" --limit 10
```

### GKE Debugging

```bash
# Check pod status
kubectl get pods -n my-app
kubectl describe pod <pod-name> -n my-app

# View logs
kubectl logs <pod-name> -n my-app -f

# Exec into pod
kubectl exec -it <pod-name> -n my-app -- /bin/sh

# Check events
kubectl get events -n my-app --sort-by='.lastTimestamp'

# Check node status
kubectl get nodes
kubectl describe node <node-name>
```

---

## Rollback

### Cloud Run Rollback

```bash
# List revisions
gcloud run revisions list --service my-app --region us-central1

# Rollback to specific revision
gcloud run services update-traffic my-app \
  --region us-central1 \
  --to-revisions <revision-name>=100

# Or rollback to previous revision
PREVIOUS_REVISION=$(gcloud run revisions list --service my-app --region us-central1 --format="value(name)" --limit 2 | tail -n 1)
gcloud run services update-traffic my-app \
  --region us-central1 \
  --to-revisions $PREVIOUS_REVISION=100
```

### GKE Rollback

```bash
# View rollout history
kubectl rollout history deployment/my-app -n my-app

# Rollback to previous version
kubectl rollout undo deployment/my-app -n my-app

# Rollback to specific revision
kubectl rollout undo deployment/my-app --to-revision=2 -n my-app
```

---

## Secrets

### Secret Manager

```bash
# Create secret
echo -n "my-secret-value" | gcloud secrets create my-secret --data-file=-

# Update secret (creates new version)
echo -n "new-secret-value" | gcloud secrets versions add my-secret --data-file=-

# View secret versions
gcloud secrets versions list my-secret

# Access secret (for debugging)
gcloud secrets versions access latest --secret my-secret

# Delete secret
gcloud secrets delete my-secret
```

### Use Secrets in Cloud Run

```bash
# Mount secret as environment variable
gcloud run services update my-app \
  --region us-central1 \
  --set-secrets "API_KEY=my-secret:latest"

# Mount secret as file
gcloud run services update my-app \
  --region us-central1 \
  --set-secrets "/secrets/api-key=my-secret:latest"
```

### Use Secrets in GKE

```bash
# Create Kubernetes secret from Secret Manager
kubectl create secret generic my-app-secrets \
  --from-literal=API_KEY=$(gcloud secrets versions access latest --secret my-secret) \
  -n my-app

# Or use Workload Identity with Secret Manager
# See: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
```

### Rotate Secrets

```bash
# Add new secret version
echo -n "new-value" | gcloud secrets versions add my-secret --data-file=-

# Cloud Run automatically picks up new version on next deployment
gcloud run services update my-app --region us-central1

# For GKE, update secret and restart pods
kubectl create secret generic my-app-secrets --from-literal=API_KEY=new-value --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment/my-app -n my-app
```

---

## Backup and Disaster Recovery

### Cloud Run Backups

- **Container images:** Stored in Artifact Registry; enable retention policies
- **Configuration:** Export service YAML for version control
  ```bash
  gcloud run services describe my-app --region us-central1 --format yaml > my-app-service.yaml
  ```
- **Secrets:** Managed by Secret Manager; enable versioning

### GKE Backups

```bash
# Install Backup for GKE (managed backup service)
gcloud container clusters update my-cluster \
  --region us-central1 \
  --enable-backup-restore

# Create backup plan
gcloud container backup-restore backup-plans create my-backup-plan \
  --cluster=projects/my-project-id/locations/us-central1/clusters/my-cluster \
  --location=us-central1 \
  --all-namespaces \
  --include-secrets \
  --include-volume-data \
  --cron-schedule="0 2 * * *"

# List backups
gcloud container backup-restore backups list --backup-plan=my-backup-plan --location=us-central1

# Restore from backup
gcloud container backup-restore restores create my-restore \
  --backup=<backup-name> \
  --location=us-central1 \
  --cluster=projects/my-project-id/locations/us-central1/clusters/my-cluster
```

### Persistent Disk Snapshots

```bash
# Create snapshot
gcloud compute disks snapshot <disk-name> --snapshot-names=my-snapshot --zone=us-central1-a

# List snapshots
gcloud compute snapshots list

# Restore from snapshot
gcloud compute disks create <new-disk-name> --source-snapshot=my-snapshot --zone=us-central1-a
```

### Multi-Region Disaster Recovery

- **Cloud Run:** Deploy to multiple regions, use Cloud Load Balancing for failover
- **GKE:** Multi-cluster setup with Config Sync or Anthos
- **Data:** Cloud SQL cross-region replicas, Cloud Storage dual-region buckets

---

## Destroy

### Cloud Run Cleanup

```bash
# Delete service
gcloud run services delete my-app --region us-central1

# Delete container images
gcloud artifacts docker images delete us-central1-docker.pkg.dev/my-project-id/my-app/my-app:latest

# Delete repository
gcloud artifacts repositories delete my-app --location us-central1

# Delete secrets
gcloud secrets delete my-secret
```

### GKE Cleanup

```bash
# Delete namespace (removes all resources)
kubectl delete namespace my-app

# Delete cluster
gcloud container clusters delete my-cluster --region us-central1

# Delete persistent disks (if not auto-deleted)
gcloud compute disks list --filter="zone:us-central1"
gcloud compute disks delete <disk-name> --zone us-central1-a
```

### Clean Up Other Resources

```bash
# Delete load balancers
gcloud compute forwarding-rules list
gcloud compute forwarding-rules delete <rule-name> --region us-central1

# Delete static IPs
gcloud compute addresses list
gcloud compute addresses delete <address-name> --region us-central1

# Delete Cloud Build triggers
gcloud builds triggers list
gcloud builds triggers delete <trigger-id>
```

---

## Cost Optimization

### Cloud Run Cost Tips

- **Scale to zero:** Default behavior; only pay when handling requests
- **Right-size resources:** Start with 256Mi/1 CPU, scale up as needed
- **Optimize cold starts:** Use Alpine Linux, minimize dependencies, keep images small
- **Use concurrency:** Set `--concurrency` to handle multiple requests per instance
- **Set min instances wisely:** Only use `--min-instances > 0` if cold starts are critical
- **Monitor billable time:** Check "Billable container instance time" metric

### GKE Cost Tips

- **Use Autopilot:** Google manages nodes, optimizes resource allocation
- **Use Spot VMs:** 60-91% discount for fault-tolerant workloads
  ```bash
  gcloud container node-pools create spot-pool \
    --cluster my-cluster \
    --spot \
    --machine-type e2-medium \
    --num-nodes 3
  ```
- **Enable cluster autoscaling:** Scale down during low traffic
- **Right-size pods:** Use VPA recommendations
- **Use preemptible nodes:** Similar to Spot VMs
- **Delete unused resources:** PVCs, load balancers, static IPs

### General GCP Cost Tips

- **Use committed use discounts:** 37-55% discount for 1-3 year commitments
- **Enable budget alerts:** Set up billing alerts at 50%, 80%, 100%
- **Use cost allocation labels:** Tag resources for cost tracking
- **Delete old container images:** Set retention policies in Artifact Registry
- **Monitor with Cloud Billing reports:** Identify cost anomalies

### Pricing Reference

- **Cloud Run:** $0.00002400/vCPU-second + $0.00000250/GiB-second + $0.40/million requests (free tier: 2M requests/month)
- **GKE Autopilot:** ~$0.04/vCPU/hour + ~$0.004/GB/hour (no cluster management fee)
- **GKE Standard:** $0.10/hour per cluster + node costs
- **Artifact Registry:** $0.10/GB/month storage
- **Cloud Logging:** $0.50/GB ingested (first 50GB free/month)

Check current pricing: https://cloud.google.com/pricing

---

## References

- **GCP Documentation:** https://cloud.google.com/docs
- **Cloud Run Documentation:** https://cloud.google.com/run/docs
- **GKE Documentation:** https://cloud.google.com/kubernetes-engine/docs
- **gcloud CLI Reference:** https://cloud.google.com/sdk/gcloud/reference
- **Cloud Architecture Center:** https://cloud.google.com/architecture
- **GCP Status:** https://status.cloud.google.com/
