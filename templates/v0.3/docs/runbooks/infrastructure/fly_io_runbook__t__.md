# Fly.io Runbook

## Overview
Operational procedures for deploying and managing applications on Fly.io.

## Prerequisites
- Fly.io account: https://fly.io/app/sign-up
- `flyctl` CLI installed: `brew install flyctl` (macOS) or `curl -L https://fly.io/install.sh | sh`
- Authenticated: `fly auth login`

---

## Setup

### Initial Provisioning

1. **Create a new app:**
   ```bash
   fly apps create <app-name>
   # Or let Fly generate a name:
   fly apps create
   ```

2. **Initialize configuration:**
   ```bash
   fly launch
   # This creates fly.toml and Dockerfile if not present
   # Follow prompts to select region, database, etc.
   ```

3. **Configure `fly.toml`:**
   ```toml
   app = "your-app-name"
   primary_region = "sjc"  # or your preferred region

   [build]
     dockerfile = "Dockerfile"  # or "Containerfile" for Podman

   [env]
     PORT = "8080"
     # Non-sensitive env vars here

   [[services]]
     internal_port = 8080
     protocol = "tcp"

     [[services.ports]]
       handlers = ["http"]
       port = 80
       force_https = true

     [[services.ports]]
       handlers = ["tls", "http"]
       port = 443

   [http_service]
     internal_port = 8080
     force_https = true
     auto_stop_machines = true
     auto_start_machines = true
     min_machines_running = 0  # scale to zero when idle

   [[vm]]
     cpu_kind = "shared"
     cpus = 1
     memory_mb = 256
   ```

4. **Set secrets:**
   ```bash
   fly secrets set DATABASE_URL="postgres://..." API_KEY="..."
   # Secrets are encrypted and injected as env vars
   ```

5. **Allocate IP addresses (if needed):**
   ```bash
   fly ips allocate-v4
   fly ips allocate-v6
   ```

---

## Deploy

### Standard Deployment

1. **Deploy from current directory:**
   ```bash
   fly deploy
   # Builds container, pushes to registry, deploys to machines
   ```

2. **Deploy with custom Dockerfile:**
   ```bash
   fly deploy --dockerfile Containerfile
   ```

3. **Deploy specific image:**
   ```bash
   fly deploy --image registry.fly.io/your-app:tag
   ```

4. **Deploy to specific region:**
   ```bash
   fly deploy --region sjc
   ```

### Deployment Options

- **No cache build:**
  ```bash
  fly deploy --no-cache
  ```

- **Deploy without health checks:**
  ```bash
  fly deploy --strategy immediate
  ```

- **Deploy with specific strategy:**
  ```bash
  fly deploy --strategy rolling  # default
  fly deploy --strategy canary   # gradual rollout
  fly deploy --strategy bluegreen
  ```

### Monitor Deployment

```bash
# Watch deployment progress
fly status

# View recent logs during deployment
fly logs

# Check machine status
fly machine list
```

---

## Scale

### Manual Scaling

1. **Scale machine count:**
   ```bash
   # Scale to specific count
   fly scale count 3

   # Scale in specific region
   fly scale count 2 --region sjc
   ```

2. **Scale machine resources:**
   ```bash
   # Change VM size
   fly scale vm shared-cpu-1x  # 1 CPU, 256MB
   fly scale vm shared-cpu-2x  # 2 CPU, 512MB
   fly scale vm performance-1x # dedicated CPU

   # Set memory
   fly scale memory 512  # MB
   ```

### Auto-Scaling

Configure in `fly.toml`:
```toml
[http_service]
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1
  max_machines_running = 10

[[http_service.concurrency]]
  type = "requests"
  hard_limit = 250
  soft_limit = 200
```

Or via CLI:
```bash
fly autoscale set min=1 max=10
fly autoscale show
fly autoscale disable
```

---

## Monitor

### Logs

```bash
# Tail logs
fly logs

# Filter by instance
fly logs --instance <instance-id>

# Filter by region
fly logs --region sjc

# JSON output
fly logs --json
```

### Metrics and Dashboards

- **Web dashboard:** https://fly.io/dashboard/<org>/<app>
- **Metrics:** CPU, memory, request rate, response time
- **Grafana:** Fly provides Prometheus metrics endpoint

### Health Checks

```bash
# Check app status
fly status

# Check machine health
fly machine list

# SSH into machine for debugging
fly ssh console
fly ssh console --select  # choose machine interactively
```

### Alerts

Configure via Fly.io dashboard:
- Health check failures
- High error rates
- Resource exhaustion

---

## Debug

### Common Issues

#### App won't start
```bash
# Check logs for errors
fly logs

# Check machine status
fly machine list

# SSH into machine
fly ssh console

# Check health check endpoint
curl https://your-app.fly.dev/health
```

#### Slow responses
```bash
# Check machine resources
fly status

# Scale up resources
fly scale memory 512
fly scale vm shared-cpu-2x

# Check logs for bottlenecks
fly logs
```

#### Connection errors
```bash
# Check IP allocation
fly ips list

# Verify DNS
dig your-app.fly.dev

# Check certificate
fly certs show your-app.fly.dev
```

### SSH Access

```bash
# SSH into a machine
fly ssh console

# Run command without interactive shell
fly ssh console -C "ps aux"

# SFTP access
fly ssh sftp shell
```

### Database Access (if using Fly Postgres)

```bash
# Connect to Postgres
fly postgres connect -a <postgres-app-name>

# Run psql commands
fly postgres connect -a <postgres-app-name> -c "SELECT * FROM users LIMIT 10;"
```

---

## Rollback

### Rollback to Previous Version

1. **List recent releases:**
   ```bash
   fly releases
   ```

2. **Rollback to specific version:**
   ```bash
   fly releases rollback <version>
   # Example: fly releases rollback v42
   ```

3. **Verify rollback:**
   ```bash
   fly status
   fly logs
   ```

### Emergency Rollback

```bash
# Immediate rollback (skips health checks)
fly releases rollback <version> --strategy immediate
```

---

## Secrets

### Manage Secrets

```bash
# Set secret
fly secrets set API_KEY="secret-value"

# Set multiple secrets
fly secrets set KEY1="value1" KEY2="value2"

# Import from file
fly secrets import < secrets.env

# List secret names (not values)
fly secrets list

# Unset secret
fly secrets unset API_KEY
```

### Rotate Secrets

```bash
# Set new secret (triggers deployment)
fly secrets set DATABASE_PASSWORD="new-password"

# Verify app restarted with new secret
fly status
fly logs
```

---

## Backup and Disaster Recovery

### Database Backups (Fly Postgres)

```bash
# Create snapshot
fly postgres backup create -a <postgres-app-name>

# List backups
fly postgres backup list -a <postgres-app-name>

# Restore from backup
fly postgres restore -a <postgres-app-name> --snapshot-id <id>
```

### Volume Backups

```bash
# List volumes
fly volumes list

# Create volume snapshot
fly volumes snapshot create <volume-id>

# List snapshots
fly volumes snapshot list

# Restore from snapshot
fly volumes create <name> --snapshot-id <id>
```

### Application State

- **Container images:** Stored in Fly.io registry; accessible via `fly releases`
- **Configuration:** `fly.toml` in version control
- **Secrets:** Managed by Fly.io; export/import via `fly secrets`

---

## Destroy

### Remove Application

1. **Scale to zero (soft shutdown):**
   ```bash
   fly scale count 0
   ```

2. **Suspend app (keeps config, stops billing):**
   ```bash
   fly apps suspend <app-name>
   ```

3. **Destroy app (permanent):**
   ```bash
   fly apps destroy <app-name>
   # Confirm when prompted
   ```

4. **Clean up resources:**
   ```bash
   # Delete volumes
   fly volumes list
   fly volumes delete <volume-id>

   # Delete databases
   fly postgres destroy -a <postgres-app-name>

   # Release IP addresses
   fly ips release <ip-address>
   ```

---

## Cost Optimization

### Tips

- **Scale to zero:** Use `auto_stop_machines = true` for low-traffic apps
- **Right-size VMs:** Start small (`shared-cpu-1x`), scale up as needed
- **Use shared CPUs:** Unless you need guaranteed performance
- **Monitor usage:** Check dashboard for resource utilization
- **Delete unused resources:** Volumes, IPs, stopped apps

### Pricing Reference

- **Free tier:** 3 shared-cpu-1x VMs (256MB) + 3GB storage
- **Compute:** ~$0.0000008/sec for shared-cpu-1x (~$2/month if always on)
- **Storage:** $0.15/GB/month for volumes
- **Bandwidth:** 100GB free egress/month, then $0.02/GB

Check current pricing: https://fly.io/docs/about/pricing/

---

## References

- **Fly.io Docs:** https://fly.io/docs/
- **flyctl Reference:** https://fly.io/docs/flyctl/
- **Community Forum:** https://community.fly.io/
- **Status Page:** https://status.fly.io/
