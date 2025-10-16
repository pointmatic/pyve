# AWS Runbook

## Overview
Operational procedures for deploying and managing applications on Amazon Web Services (AWS).

## Prerequisites
- AWS account: https://aws.amazon.com/
- AWS CLI installed: `brew install awscli` (macOS) or https://aws.amazon.com/cli/
- Authenticated: `aws configure` (provide Access Key ID, Secret Access Key, region)
- Terraform or CloudFormation for IaC (recommended)

---

## Setup

### Initial Provisioning

This runbook assumes you're using **AWS Elastic Container Service (ECS) with Fargate** for containerized apps. Adjust for EC2, Lambda, or other services as needed.

1. **Create VPC and networking (if not using default):**
   ```bash
   # Using AWS CLI (or use Terraform/CloudFormation)
   aws ec2 create-vpc --cidr-block 10.0.0.0/16
   aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.0.1.0/24 --availability-zone us-east-1a
   aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.0.2.0/24 --availability-zone us-east-1b
   aws ec2 create-internet-gateway
   aws ec2 attach-internet-gateway --vpc-id <vpc-id> --internet-gateway-id <igw-id>
   ```

2. **Create ECR repository for container images:**
   ```bash
   aws ecr create-repository --repository-name my-app
   ```

3. **Build and push Docker image:**
   ```bash
   # Authenticate Docker to ECR
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

   # Build image (or use Podman: podman build)
   docker build -t my-app:latest .

   # Tag image
   docker tag my-app:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/my-app:latest

   # Push image
   docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
   ```

4. **Create ECS cluster:**
   ```bash
   aws ecs create-cluster --cluster-name my-cluster
   ```

5. **Create task definition:**
   ```json
   {
     "family": "my-app",
     "networkMode": "awsvpc",
     "requiresCompatibilities": ["FARGATE"],
     "cpu": "256",
     "memory": "512",
     "containerDefinitions": [
       {
         "name": "my-app",
         "image": "<account-id>.dkr.ecr.us-east-1.amazonaws.com/my-app:latest",
         "portMappings": [
           {
             "containerPort": 8080,
             "protocol": "tcp"
           }
         ],
         "environment": [
           {"name": "PORT", "value": "8080"}
         ],
         "secrets": [
           {
             "name": "DATABASE_URL",
             "valueFrom": "arn:aws:secretsmanager:us-east-1:<account-id>:secret:my-app/db-url"
           }
         ],
         "logConfiguration": {
           "logDriver": "awslogs",
           "options": {
             "awslogs-group": "/ecs/my-app",
             "awslogs-region": "us-east-1",
             "awslogs-stream-prefix": "ecs"
           }
         }
       }
     ]
   }
   ```

   Register task definition:
   ```bash
   aws ecs register-task-definition --cli-input-json file://task-definition.json
   ```

6. **Create Application Load Balancer (ALB):**
   ```bash
   aws elbv2 create-load-balancer --name my-alb --subnets <subnet-id-1> <subnet-id-2> --security-groups <sg-id>
   aws elbv2 create-target-group --name my-targets --protocol HTTP --port 8080 --vpc-id <vpc-id> --target-type ip
   aws elbv2 create-listener --load-balancer-arn <alb-arn> --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=<tg-arn>
   ```

7. **Create ECS service:**
   ```bash
   aws ecs create-service \
     --cluster my-cluster \
     --service-name my-service \
     --task-definition my-app \
     --desired-count 2 \
     --launch-type FARGATE \
     --network-configuration "awsvpcConfiguration={subnets=[<subnet-id-1>,<subnet-id-2>],securityGroups=[<sg-id>],assignPublicIp=ENABLED}" \
     --load-balancers "targetGroupArn=<tg-arn>,containerName=my-app,containerPort=8080"
   ```

---

## Deploy

### Standard Deployment

1. **Build and push new image:**
   ```bash
   docker build -t my-app:v2 .
   docker tag my-app:v2 <account-id>.dkr.ecr.us-east-1.amazonaws.com/my-app:v2
   docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/my-app:v2
   ```

2. **Update task definition with new image:**
   ```bash
   # Modify task-definition.json with new image tag
   aws ecs register-task-definition --cli-input-json file://task-definition.json
   ```

3. **Update service to use new task definition:**
   ```bash
   aws ecs update-service --cluster my-cluster --service my-service --task-definition my-app:2
   ```

4. **Monitor deployment:**
   ```bash
   aws ecs describe-services --cluster my-cluster --services my-service
   aws ecs list-tasks --cluster my-cluster --service-name my-service
   ```

### Blue-Green Deployment

Use **AWS CodeDeploy** with ECS:
```bash
# Create CodeDeploy application and deployment group
aws deploy create-application --application-name my-app --compute-platform ECS
aws deploy create-deployment-group --application-name my-app --deployment-group-name my-dg --service-role-arn <role-arn> --ecs-services clusterName=my-cluster,serviceName=my-service --load-balancer-info targetGroupPairInfoList=[...]

# Trigger deployment
aws deploy create-deployment --application-name my-app --deployment-group-name my-dg --revision revisionType=AppSpecContent,appSpecContent={content=...}
```

---

## Scale

### Manual Scaling

```bash
# Scale ECS service
aws ecs update-service --cluster my-cluster --service my-service --desired-count 5

# Scale Fargate task CPU/memory (update task definition)
# Modify task-definition.json: "cpu": "512", "memory": "1024"
aws ecs register-task-definition --cli-input-json file://task-definition.json
aws ecs update-service --cluster my-cluster --service my-service --task-definition my-app:3 --force-new-deployment
```

### Auto-Scaling

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/my-cluster/my-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

# Create scaling policy (target tracking)
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/my-cluster/my-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

Example `scaling-policy.json`:
```json
{
  "TargetValue": 70.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
  },
  "ScaleInCooldown": 300,
  "ScaleOutCooldown": 60
}
```

---

## Monitor

### CloudWatch Logs

```bash
# View logs
aws logs tail /ecs/my-app --follow

# Filter logs
aws logs filter-log-events --log-group-name /ecs/my-app --filter-pattern "ERROR"

# Create log insights query
aws logs start-query --log-group-name /ecs/my-app --start-time $(date -u -d '1 hour ago' +%s) --end-time $(date +%s) --query-string "fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc"
```

### CloudWatch Metrics

- **ECS metrics:** CPUUtilization, MemoryUtilization, TaskCount
- **ALB metrics:** RequestCount, TargetResponseTime, HTTPCode_Target_5XX_Count
- **Custom metrics:** Use CloudWatch SDK to publish app-specific metrics

### CloudWatch Dashboards

Create dashboards via AWS Console or CLI:
```bash
aws cloudwatch put-dashboard --dashboard-name my-app --dashboard-body file://dashboard.json
```

### CloudWatch Alarms

```bash
# Create alarm for high CPU
aws cloudwatch put-metric-alarm \
  --alarm-name high-cpu \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=ServiceName,Value=my-service Name=ClusterName,Value=my-cluster \
  --alarm-actions <sns-topic-arn>
```

---

## Debug

### Common Issues

#### Tasks failing to start
```bash
# Check task status
aws ecs describe-tasks --cluster my-cluster --tasks <task-id>

# Check stopped tasks
aws ecs list-tasks --cluster my-cluster --desired-status STOPPED
aws ecs describe-tasks --cluster my-cluster --tasks <stopped-task-id>

# Common causes:
# - Image pull errors (check ECR permissions)
# - Insufficient memory/CPU
# - Health check failures
# - Security group blocking traffic
```

#### High latency
```bash
# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization --dimensions Name=ServiceName,Value=my-service --start-time $(date -u -d '1 hour ago' +%s) --end-time $(date +%s) --period 300 --statistics Average

# Scale up if needed
aws ecs update-service --cluster my-cluster --service my-service --desired-count 5
```

#### Connection errors
```bash
# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>

# Check ALB health
aws elbv2 describe-load-balancers --load-balancer-arns <alb-arn>

# Check DNS
dig my-app.example.com
```

### ECS Exec (SSH-like access)

```bash
# Enable ECS Exec on service
aws ecs update-service --cluster my-cluster --service my-service --enable-execute-command

# Connect to running task
aws ecs execute-command --cluster my-cluster --task <task-id> --container my-app --interactive --command "/bin/sh"
```

---

## Rollback

### Rollback to Previous Task Definition

```bash
# List task definitions
aws ecs list-task-definitions --family-prefix my-app

# Update service to previous version
aws ecs update-service --cluster my-cluster --service my-service --task-definition my-app:1
```

### Emergency Rollback

```bash
# Force immediate deployment (skips health checks)
aws ecs update-service --cluster my-cluster --service my-service --task-definition my-app:1 --force-new-deployment --deployment-configuration "minimumHealthyPercent=0,maximumPercent=100"
```

---

## Secrets

### AWS Secrets Manager

```bash
# Create secret
aws secretsmanager create-secret --name my-app/database-url --secret-string "postgres://..."

# Update secret
aws secretsmanager update-secret --secret-id my-app/database-url --secret-string "postgres://new-value"

# Retrieve secret (for debugging)
aws secretsmanager get-secret-value --secret-id my-app/database-url

# Delete secret (with recovery window)
aws secretsmanager delete-secret --secret-id my-app/database-url --recovery-window-in-days 7
```

### Rotate Secrets

```bash
# Update secret
aws secretsmanager update-secret --secret-id my-app/api-key --secret-string "new-key"

# Force service redeployment to pick up new secret
aws ecs update-service --cluster my-cluster --service my-service --force-new-deployment
```

---

## Backup and Disaster Recovery

### RDS Backups (if using RDS)

```bash
# Create snapshot
aws rds create-db-snapshot --db-instance-identifier my-db --db-snapshot-identifier my-db-snapshot-$(date +%Y%m%d)

# List snapshots
aws rds describe-db-snapshots --db-instance-identifier my-db

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot --db-instance-identifier my-db-restored --db-snapshot-identifier my-db-snapshot-20250101
```

### EBS Snapshots (if using EC2)

```bash
# Create snapshot
aws ec2 create-snapshot --volume-id <vol-id> --description "Backup $(date)"

# List snapshots
aws ec2 describe-snapshots --owner-ids self

# Restore snapshot
aws ec2 create-volume --snapshot-id <snap-id> --availability-zone us-east-1a
```

### Multi-Region Disaster Recovery

- **Cross-region replication:** Enable for RDS, S3, ECR
- **Route 53 failover:** Configure health checks and failover routing
- **Backup strategy:** Regular snapshots to S3 with cross-region replication

---

## Destroy

### Remove Application

1. **Scale service to zero:**
   ```bash
   aws ecs update-service --cluster my-cluster --service my-service --desired-count 0
   ```

2. **Delete service:**
   ```bash
   aws ecs delete-service --cluster my-cluster --service my-service --force
   ```

3. **Delete load balancer:**
   ```bash
   aws elbv2 delete-load-balancer --load-balancer-arn <alb-arn>
   aws elbv2 delete-target-group --target-group-arn <tg-arn>
   ```

4. **Delete ECS cluster:**
   ```bash
   aws ecs delete-cluster --cluster my-cluster
   ```

5. **Delete ECR repository:**
   ```bash
   aws ecr delete-repository --repository-name my-app --force
   ```

6. **Clean up other resources:**
   ```bash
   # Delete CloudWatch log groups
   aws logs delete-log-group --log-group-name /ecs/my-app

   # Delete secrets
   aws secretsmanager delete-secret --secret-id my-app/database-url --force-delete-without-recovery

   # Delete VPC resources (if created)
   # Delete subnets, route tables, internet gateway, VPC
   ```

---

## Cost Optimization

### Tips

- **Use Fargate Spot:** 70% discount for fault-tolerant workloads
- **Right-size tasks:** Start with smallest CPU/memory, scale up as needed
- **Use reserved capacity:** Commit to Savings Plans for 30-70% discount
- **Enable auto-scaling:** Scale down during low-traffic periods
- **Use S3 lifecycle policies:** Move infrequent data to Glacier
- **Delete unused resources:** Old ECR images, EBS snapshots, stopped instances
- **Monitor with Cost Explorer:** Identify cost anomalies and optimization opportunities

### Pricing Reference

- **Fargate:** ~$0.04/vCPU/hour + ~$0.004/GB/hour
- **ALB:** ~$0.0225/hour + $0.008/LCU-hour
- **ECR:** $0.10/GB/month storage
- **CloudWatch Logs:** $0.50/GB ingested, $0.03/GB stored
- **Data transfer:** First 100GB free/month, then $0.09/GB

Check current pricing: https://aws.amazon.com/pricing/

---

## References

- **AWS Documentation:** https://docs.aws.amazon.com/
- **ECS Documentation:** https://docs.aws.amazon.com/ecs/
- **AWS CLI Reference:** https://awscli.amazonaws.com/v2/documentation/api/latest/index.html
- **AWS Well-Architected Framework:** https://aws.amazon.com/architecture/well-architected/
- **AWS Status:** https://health.aws.amazon.com/health/status
