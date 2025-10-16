# Cloud Managed Databases Runbook

## Overview

This runbook covers operations for managed database services from major cloud providers. Managed services handle infrastructure, backups, patching, and high availability, allowing you to focus on application development.

**Covered services:**
- **AWS:** RDS, Aurora, DynamoDB, ElastiCache, DocumentDB
- **GCP:** Cloud SQL, Cloud Spanner, Firestore, Memorystore
- **Azure:** Azure Database, Cosmos DB, Azure Cache for Redis

---

## AWS Services

### Amazon RDS (Relational Database Service)

**Supported engines:** PostgreSQL, MySQL, MariaDB, Oracle, SQL Server

#### Creating RDS Instance

**Via AWS CLI:**
```bash
aws rds create-db-instance \
  --db-instance-identifier mydb \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.3 \
  --master-username admin \
  --master-user-password SecurePassword123 \
  --allocated-storage 20 \
  --storage-type gp3 \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name my-subnet-group \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --preferred-maintenance-window "mon:04:00-mon:05:00" \
  --multi-az \
  --publicly-accessible false \
  --storage-encrypted \
  --enable-cloudwatch-logs-exports '["postgresql"]' \
  --tags Key=Environment,Value=Production
```

**Via Terraform:**
```hcl
resource "aws_db_instance" "mydb" {
  identifier     = "mydb"
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  storage_type          = "gp3"
  storage_encrypted     = true
  
  db_name  = "myapp"
  username = "admin"
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  multi_az               = true
  publicly_accessible    = false
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  tags = {
    Environment = "Production"
  }
}
```

#### Backup & Recovery

**Automated backups:**
- Enabled by default
- Retention: 1-35 days
- Backup window: Specify preferred time
- Stored in S3 (managed by AWS)

**Manual snapshots:**
```bash
# Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier mydb \
  --db-snapshot-identifier mydb-snapshot-$(date +%Y%m%d)

# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier mydb

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier mydb-restored \
  --db-snapshot-identifier mydb-snapshot-20240115

# Delete snapshot
aws rds delete-db-snapshot \
  --db-snapshot-identifier mydb-snapshot-20240115
```

**Point-in-time recovery:**
```bash
# Restore to specific time
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier mydb \
  --target-db-instance-identifier mydb-pitr \
  --restore-time 2024-01-15T14:30:00Z

# Or restore to latest restorable time
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier mydb \
  --target-db-instance-identifier mydb-pitr \
  --use-latest-restorable-time
```

#### Scaling

**Vertical scaling (instance size):**
```bash
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --db-instance-class db.r5.large \
  --apply-immediately
```

**Storage scaling:**
```bash
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --allocated-storage 100 \
  --apply-immediately
```

**Read replicas:**
```bash
# Create read replica
aws rds create-db-instance-read-replica \
  --db-instance-identifier mydb-replica \
  --source-db-instance-identifier mydb \
  --db-instance-class db.t3.micro

# Promote read replica to standalone
aws rds promote-read-replica \
  --db-instance-identifier mydb-replica
```

#### Monitoring

**CloudWatch metrics:**
- CPUUtilization
- DatabaseConnections
- FreeableMemory
- FreeStorageSpace
- ReadLatency / WriteLatency
- ReadThroughput / WriteThroughput

**View metrics:**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=mydb \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 3600 \
  --statistics Average
```

**Enhanced Monitoring:**
```bash
# Enable enhanced monitoring (1-60 second intervals)
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --monitoring-interval 60 \
  --monitoring-role-arn arn:aws:iam::123456789012:role/rds-monitoring-role
```

**Performance Insights:**
```bash
# Enable Performance Insights
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --enable-performance-insights \
  --performance-insights-retention-period 7
```

### Amazon Aurora

**Advantages over RDS:**
- 5x throughput of PostgreSQL, 3x of MySQL
- Auto-scaling storage (10GB to 128TB)
- Up to 15 read replicas
- Global databases (cross-region replication)
- Serverless option

#### Creating Aurora Cluster

```bash
# Create Aurora cluster
aws rds create-db-cluster \
  --db-cluster-identifier myaurora \
  --engine aurora-postgresql \
  --engine-version 15.3 \
  --master-username admin \
  --master-user-password SecurePassword123 \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name my-subnet-group \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00"

# Create cluster instances
aws rds create-db-instance \
  --db-instance-identifier myaurora-instance-1 \
  --db-instance-class db.r5.large \
  --engine aurora-postgresql \
  --db-cluster-identifier myaurora
```

#### Aurora Serverless

**Create serverless cluster:**
```bash
aws rds create-db-cluster \
  --db-cluster-identifier myaurora-serverless \
  --engine aurora-postgresql \
  --engine-mode serverless \
  --engine-version 13.9 \
  --master-username admin \
  --master-user-password SecurePassword123 \
  --scaling-configuration MinCapacity=2,MaxCapacity=16,AutoPause=true,SecondsUntilAutoPause=300
```

**Scaling configuration:**
- MinCapacity: 2-256 ACUs (Aurora Capacity Units)
- MaxCapacity: 2-256 ACUs
- AutoPause: Pause after inactivity
- SecondsUntilAutoPause: 300-86400 seconds

#### Aurora Global Database

**Create global database:**
```bash
# Create primary cluster
aws rds create-global-cluster \
  --global-cluster-identifier myglobal \
  --engine aurora-postgresql

# Add primary region
aws rds create-db-cluster \
  --db-cluster-identifier myaurora-primary \
  --engine aurora-postgresql \
  --global-cluster-identifier myglobal \
  --region us-east-1

# Add secondary region
aws rds create-db-cluster \
  --db-cluster-identifier myaurora-secondary \
  --engine aurora-postgresql \
  --global-cluster-identifier myglobal \
  --region eu-west-1
```

### Amazon DynamoDB

**NoSQL key-value and document database**

#### Creating Table

```bash
aws dynamodb create-table \
  --table-name Users \
  --attribute-definitions \
    AttributeName=UserId,AttributeType=S \
    AttributeName=Email,AttributeType=S \
  --key-schema \
    AttributeName=UserId,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=EmailIndex,KeySchema=[{AttributeName=Email,KeyType=HASH}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Environment,Value=Production
```

#### Backup & Recovery

**On-demand backups:**
```bash
# Create backup
aws dynamodb create-backup \
  --table-name Users \
  --backup-name users-backup-$(date +%Y%m%d)

# List backups
aws dynamodb list-backups --table-name Users

# Restore from backup
aws dynamodb restore-table-from-backup \
  --target-table-name Users-Restored \
  --backup-arn arn:aws:dynamodb:us-east-1:123456789012:table/Users/backup/xxxxx
```

**Point-in-time recovery:**
```bash
# Enable PITR
aws dynamodb update-continuous-backups \
  --table-name Users \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

# Restore to specific time
aws dynamodb restore-table-to-point-in-time \
  --source-table-name Users \
  --target-table-name Users-PITR \
  --restore-date-time 2024-01-15T14:30:00Z
```

#### Auto-scaling

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace dynamodb \
  --resource-id table/Users \
  --scalable-dimension dynamodb:table:ReadCapacityUnits \
  --min-capacity 5 \
  --max-capacity 100

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace dynamodb \
  --resource-id table/Users \
  --scalable-dimension dynamodb:table:ReadCapacityUnits \
  --policy-name Users-read-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration \
    '{"TargetValue":70.0,"PredefinedMetricSpecification":{"PredefinedMetricType":"DynamoDBReadCapacityUtilization"}}'
```

### Amazon ElastiCache

**Managed Redis and Memcached**

#### Creating Redis Cluster

```bash
aws elasticache create-replication-group \
  --replication-group-id myredis \
  --replication-group-description "My Redis cluster" \
  --engine redis \
  --engine-version 7.0 \
  --cache-node-type cache.r5.large \
  --num-cache-clusters 3 \
  --automatic-failover-enabled \
  --multi-az-enabled \
  --cache-subnet-group-name my-subnet-group \
  --security-group-ids sg-xxxxx \
  --snapshot-retention-limit 7 \
  --snapshot-window "03:00-05:00"
```

#### Backup & Recovery

```bash
# Create snapshot
aws elasticache create-snapshot \
  --replication-group-id myredis \
  --snapshot-name myredis-snapshot-$(date +%Y%m%d)

# Restore from snapshot
aws elasticache create-replication-group \
  --replication-group-id myredis-restored \
  --replication-group-description "Restored from snapshot" \
  --snapshot-name myredis-snapshot-20240115
```

---

## GCP Services

### Cloud SQL

**Supported engines:** PostgreSQL, MySQL, SQL Server

#### Creating Cloud SQL Instance

**Via gcloud CLI:**
```bash
gcloud sql instances create mydb \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-central1 \
  --root-password=SecurePassword123 \
  --backup-start-time=03:00 \
  --maintenance-window-day=SUN \
  --maintenance-window-hour=04 \
  --enable-bin-log \
  --backup-location=us \
  --availability-type=REGIONAL \
  --storage-type=SSD \
  --storage-size=10GB \
  --storage-auto-increase
```

**Via Terraform:**
```hcl
resource "google_sql_database_instance" "mydb" {
  name             = "mydb"
  database_version = "POSTGRES_15"
  region           = "us-central1"
  
  settings {
    tier = "db-f1-micro"
    
    backup_configuration {
      enabled            = true
      start_time         = "03:00"
      location           = "us"
      point_in_time_recovery_enabled = true
    }
    
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
    }
    
    maintenance_window {
      day  = 7  # Sunday
      hour = 4
    }
    
    availability_type = "REGIONAL"
    
    disk_type = "PD_SSD"
    disk_size = 10
    disk_autoresize = true
  }
}
```

#### Backup & Recovery

**On-demand backups:**
```bash
# Create backup
gcloud sql backups create \
  --instance=mydb \
  --description="Manual backup $(date +%Y%m%d)"

# List backups
gcloud sql backups list --instance=mydb

# Restore from backup
gcloud sql backups restore BACKUP_ID \
  --backup-instance=mydb \
  --backup-id=1234567890
```

**Point-in-time recovery:**
```bash
# Clone instance to specific time
gcloud sql instances clone mydb mydb-pitr \
  --point-in-time=2024-01-15T14:30:00Z
```

#### Scaling

**Vertical scaling:**
```bash
gcloud sql instances patch mydb \
  --tier=db-n1-standard-2
```

**Storage scaling:**
```bash
gcloud sql instances patch mydb \
  --storage-size=100GB
```

**Read replicas:**
```bash
# Create read replica
gcloud sql instances create mydb-replica \
  --master-instance-name=mydb \
  --tier=db-f1-micro \
  --region=us-east1

# Promote read replica
gcloud sql instances promote-replica mydb-replica
```

#### Monitoring

**Stackdriver metrics:**
- database/cpu/utilization
- database/memory/utilization
- database/disk/utilization
- database/network/connections
- database/replication/replica_lag

**View metrics:**
```bash
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/cpu/utilization" AND resource.labels.database_id="project:mydb"' \
  --interval-start-time=2024-01-15T00:00:00Z \
  --interval-end-time=2024-01-15T23:59:59Z
```

### Cloud Spanner

**Globally distributed, horizontally scalable relational database**

#### Creating Spanner Instance

```bash
gcloud spanner instances create myspanner \
  --config=regional-us-central1 \
  --description="My Spanner instance" \
  --nodes=1

# Create database
gcloud spanner databases create mydb \
  --instance=myspanner \
  --ddl='CREATE TABLE Users (
    UserId STRING(36) NOT NULL,
    Email STRING(255),
    Name STRING(255)
  ) PRIMARY KEY (UserId)'
```

#### Backup & Recovery

```bash
# Create backup
gcloud spanner backups create mybackup \
  --instance=myspanner \
  --database=mydb \
  --retention-period=7d

# Restore from backup
gcloud spanner databases restore \
  --destination-database=mydb-restored \
  --destination-instance=myspanner \
  --source-backup=mybackup \
  --source-instance=myspanner
```

### Firestore

**NoSQL document database**

#### Creating Database

```bash
gcloud firestore databases create \
  --location=us-central \
  --type=firestore-native
```

#### Backup & Recovery

**Export data:**
```bash
gcloud firestore export gs://my-bucket/firestore-backup-$(date +%Y%m%d)
```

**Import data:**
```bash
gcloud firestore import gs://my-bucket/firestore-backup-20240115
```

### Memorystore (Redis)

#### Creating Redis Instance

```bash
gcloud redis instances create myredis \
  --size=1 \
  --region=us-central1 \
  --redis-version=redis_7_0 \
  --tier=standard \
  --replica-count=1
```

---

## Azure Services

### Azure Database

**Supported engines:** PostgreSQL, MySQL, MariaDB

#### Creating Azure Database

**Via Azure CLI:**
```bash
az postgres flexible-server create \
  --resource-group myResourceGroup \
  --name mydb \
  --location eastus \
  --admin-user myadmin \
  --admin-password SecurePassword123 \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32 \
  --version 15 \
  --high-availability Enabled \
  --backup-retention 7
```

#### Backup & Recovery

**On-demand backups:**
```bash
# Backups are automatic, but you can restore to a point in time
az postgres flexible-server restore \
  --resource-group myResourceGroup \
  --name mydb-restored \
  --source-server mydb \
  --restore-time "2024-01-15T14:30:00Z"
```

#### Scaling

```bash
# Scale compute
az postgres flexible-server update \
  --resource-group myResourceGroup \
  --name mydb \
  --sku-name Standard_D2s_v3

# Scale storage
az postgres flexible-server update \
  --resource-group myResourceGroup \
  --name mydb \
  --storage-size 64
```

#### Read Replicas

```bash
az postgres flexible-server replica create \
  --resource-group myResourceGroup \
  --name mydb-replica \
  --source-server mydb \
  --location westus
```

### Azure Cosmos DB

**Globally distributed, multi-model NoSQL database**

#### Creating Cosmos DB Account

```bash
az cosmosdb create \
  --resource-group myResourceGroup \
  --name mycosmosdb \
  --kind GlobalDocumentDB \
  --locations regionName=eastus failoverPriority=0 \
  --locations regionName=westus failoverPriority=1 \
  --default-consistency-level Session \
  --enable-automatic-failover true
```

#### Backup & Recovery

**Continuous backup:**
```bash
# Enable continuous backup
az cosmosdb update \
  --resource-group myResourceGroup \
  --name mycosmosdb \
  --backup-policy-type Continuous

# Restore to point in time
az cosmosdb restore \
  --resource-group myResourceGroup \
  --account-name mycosmosdb-restored \
  --source-account-name mycosmosdb \
  --restore-timestamp "2024-01-15T14:30:00Z"
```

### Azure Cache for Redis

#### Creating Redis Cache

```bash
az redis create \
  --resource-group myResourceGroup \
  --name myredis \
  --location eastus \
  --sku Standard \
  --vm-size c1 \
  --enable-non-ssl-port false
```

#### Backup & Recovery

```bash
# Export data
az redis export \
  --resource-group myResourceGroup \
  --name myredis \
  --prefix backup-$(date +%Y%m%d) \
  --container https://mystorageaccount.blob.core.windows.net/backups

# Import data
az redis import \
  --resource-group myResourceGroup \
  --name myredis \
  --files https://mystorageaccount.blob.core.windows.net/backups/backup-20240115.rdb
```

---

## Cost Optimization

### General Strategies

**Right-size instances:**
- Monitor actual CPU/memory usage
- Downsize over-provisioned instances
- Use burstable instances for variable workloads

**Use reserved capacity:**
- **AWS:** Reserved Instances (1-3 years, 30-70% discount)
- **GCP:** Committed Use Discounts (1-3 years, up to 57% discount)
- **Azure:** Reserved Capacity (1-3 years, up to 65% discount)

**Auto-scaling:**
- Enable auto-scaling for read replicas
- Use serverless options for variable workloads (Aurora Serverless, Cosmos DB serverless)

**Storage optimization:**
- Delete old backups
- Use appropriate storage tiers
- Enable compression

**Monitor costs:**
- Set budget alerts
- Tag resources for cost allocation
- Review cost reports monthly

### Service-Specific Tips

**AWS RDS:**
- Use gp3 instead of gp2 storage (better performance, lower cost)
- Delete unused snapshots
- Use Aurora Serverless for dev/test environments

**GCP Cloud SQL:**
- Use committed use discounts
- Enable storage auto-increase to avoid over-provisioning
- Use Cloud SQL Proxy to avoid public IPs

**Azure Database:**
- Use burstable tiers for dev/test
- Enable auto-pause for serverless
- Use read replicas in same region to avoid data transfer costs

---

## Security Best Practices

### Network Security

**AWS:**
- Use VPC and security groups
- Disable public accessibility
- Use VPC endpoints for private connectivity

**GCP:**
- Use private IP addresses
- Configure authorized networks
- Use Cloud SQL Proxy

**Azure:**
- Use VNet integration
- Configure firewall rules
- Use Private Link

### Encryption

**At rest:**
- Enable encryption at rest (usually default)
- Use customer-managed keys (CMK) for compliance

**In transit:**
- Enforce SSL/TLS connections
- Use certificate validation

### Access Control

**AWS:**
- Use IAM roles and policies
- Enable IAM database authentication
- Use Secrets Manager for credentials

**GCP:**
- Use Cloud IAM
- Enable Cloud SQL IAM authentication
- Use Secret Manager

**Azure:**
- Use Azure AD authentication
- Use Managed Identities
- Use Key Vault for secrets

### Audit Logging

**AWS:**
- Enable CloudWatch Logs
- Use CloudTrail for API calls
- Enable RDS Enhanced Monitoring

**GCP:**
- Enable Cloud Logging
- Use Cloud Audit Logs
- Enable query insights

**Azure:**
- Enable diagnostic logs
- Use Azure Monitor
- Enable auditing

---

## Monitoring & Alerting

### Key Metrics to Monitor

**All platforms:**
- CPU utilization (>80%)
- Memory utilization (>80%)
- Storage utilization (>80%)
- Connection count (>80% of max)
- Replication lag (>60 seconds)
- Failed connections
- Slow queries

### Alerting Tools

**AWS:**
- CloudWatch Alarms
- SNS for notifications
- EventBridge for automation

**GCP:**
- Cloud Monitoring
- Alerting policies
- Pub/Sub for notifications

**Azure:**
- Azure Monitor
- Action Groups
- Logic Apps for automation

---

## References

**AWS:**
- RDS: https://docs.aws.amazon.com/rds/
- Aurora: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/
- DynamoDB: https://docs.aws.amazon.com/dynamodb/
- ElastiCache: https://docs.aws.amazon.com/elasticache/

**GCP:**
- Cloud SQL: https://cloud.google.com/sql/docs
- Cloud Spanner: https://cloud.google.com/spanner/docs
- Firestore: https://cloud.google.com/firestore/docs
- Memorystore: https://cloud.google.com/memorystore/docs

**Azure:**
- Azure Database: https://docs.microsoft.com/azure/postgresql/
- Cosmos DB: https://docs.microsoft.com/azure/cosmos-db/
- Azure Cache for Redis: https://docs.microsoft.com/azure/azure-cache-for-redis/

---

## Related Documentation

- **Operations Guide:** `docs/guides/persistence_operations_guide__t__.md` - General strategies and concepts
- **Persistence Guide:** `docs/guides/persistence_guide__t__.md` - Choosing storage technologies
- **Database-specific runbooks:** PostgreSQL, MySQL, MongoDB, Redis runbooks for self-managed operations
- **Infrastructure runbooks:** `docs/runbooks/infrastructure/` - AWS, GCP, Azure infrastructure operations
