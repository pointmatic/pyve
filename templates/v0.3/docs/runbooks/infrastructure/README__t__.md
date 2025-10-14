# Runbooks

## Overview
This directory contains operational runbooks for deploying and managing applications on various platforms. Each runbook provides step-by-step procedures for common operational tasks.

## Purpose
- **Standardize operations:** Consistent procedures across team members
- **Reduce errors:** Clear, tested instructions for critical tasks
- **Onboard quickly:** New team members can execute operations safely
- **Document tribal knowledge:** Capture operational expertise

## Available Runbooks

### Cloud Platforms
- **[Fly.io](fly_io_runbook.md)** - Simple, developer-friendly edge deployment
- **[AWS](aws_runbook.md)** - Enterprise cloud with ECS/Fargate focus
- **[GCP](gcp_runbook.md)** - Google Cloud Platform with Cloud Run/GKE
- **[Kubernetes](kubernetes_runbook.md)** - Container orchestration (EKS, GKE, AKS, self-managed)

### Coming Soon
- **Azure** - Microsoft Azure with Container Apps/AKS
- **Heroku** - Platform-as-a-Service for rapid deployment

## Runbook Structure

Each runbook follows a consistent structure:

1. **Overview** - Platform summary and use cases
2. **Prerequisites** - Required tools, credentials, access
3. **Setup** - Initial provisioning and configuration
4. **Deploy** - Deployment procedures and strategies
5. **Scale** - Manual and auto-scaling operations
6. **Monitor** - Logging, metrics, dashboards, alerts
7. **Debug** - Common issues and troubleshooting steps
8. **Rollback** - Procedures to revert to previous versions
9. **Secrets** - Managing sensitive configuration
10. **Backup and Disaster Recovery** - Data protection and restoration
11. **Destroy** - Safe teardown procedures
12. **Cost Optimization** - Tips to reduce infrastructure costs
13. **References** - Links to official documentation

## When to Use Runbooks

### During Development
- Setting up staging environments
- Testing deployment procedures
- Validating infrastructure changes

### During Incidents
- Quick reference for emergency procedures
- Rollback steps when deployments fail
- Debugging production issues

### During Onboarding
- Teaching new team members operational procedures
- Establishing consistent practices
- Building confidence with production systems

### During Audits
- Demonstrating operational maturity
- Documenting compliance procedures
- Showing disaster recovery capabilities

## Best Practices

### Writing Runbooks
- **Be specific:** Include exact commands, not just concepts
- **Test regularly:** Verify procedures work as documented
- **Keep current:** Update when infrastructure changes
- **Add context:** Explain why, not just how
- **Include examples:** Real values (sanitized) help understanding

### Using Runbooks
- **Follow exactly:** Don't improvise during incidents
- **Update as you go:** Note discrepancies for later fixes
- **Share learnings:** Document new issues and solutions
- **Practice regularly:** Run through procedures during calm periods
- **Automate when possible:** Convert manual steps to scripts/IaC

### Maintaining Runbooks
- **Review quarterly:** Ensure accuracy and relevance
- **Version control:** Track changes in Git
- **Peer review:** Have others validate procedures
- **Link to monitoring:** Reference dashboards and alerts
- **Document ownership:** Assign maintainers per runbook

## Creating New Runbooks

To add a runbook for a new platform:

1. **Copy an existing runbook** as a template
2. **Customize sections** for the target platform
3. **Test all procedures** in a non-production environment
4. **Add platform-specific sections** as needed (e.g., "Lambda Functions" for AWS)
5. **Link from this README** in the appropriate category
6. **Update infrastructure_guide.md** with platform comparison

### Runbook Template Outline

```markdown
# Platform Name Runbook

## Overview
Brief description and use cases

## Prerequisites
- Required tools
- Access requirements
- Initial setup

## Setup
Initial provisioning steps

## Deploy
Deployment procedures

## Scale
Scaling operations

## Monitor
Logging and metrics

## Debug
Common issues and solutions

## Rollback
Revert procedures

## Secrets
Secret management

## Backup and Disaster Recovery
Data protection

## Destroy
Teardown procedures

## Cost Optimization
Cost-saving tips

## References
Official documentation links
```

## Integration with Other Documentation

Runbooks complement other project documentation:

- **[Infrastructure Guide](../guides/infrastructure_guide.md)** - Patterns and principles (platform-agnostic)
- **[Technical Design Spec](../specs/technical_design_spec.md)** - Architecture and design decisions
- **[Codebase Spec](../specs/codebase_spec.md)** - As-built infrastructure documentation
- **[Implementation Options Spec](../specs/implementation_options_spec.md)** - Platform selection rationale

## Emergency Contacts

Document on-call rotation and escalation procedures:

```markdown
### On-Call Rotation
- Primary: [Name] - [Contact]
- Secondary: [Name] - [Contact]
- Manager: [Name] - [Contact]

### Escalation Path
1. On-call engineer (15 min response)
2. Team lead (30 min response)
3. Engineering manager (1 hour response)

### External Support
- Platform support: [Link to support portal]
- Vendor SLA: [Response time commitments]
```

## Incident Response

Link to incident response procedures:

1. **Detect** - Monitoring alerts, user reports
2. **Assess** - Severity, impact, affected users
3. **Mitigate** - Immediate actions (rollback, scale, failover)
4. **Communicate** - Status updates to stakeholders
5. **Resolve** - Root cause fix and verification
6. **Document** - Post-mortem and lessons learned

## Compliance and Security

For regulated environments, document:

- **Change approval process** - Who can deploy to production
- **Audit logging** - What operations are logged and where
- **Access controls** - Who has admin access and how it's granted
- **Data handling** - Backup retention, encryption requirements
- **Incident reporting** - When and how to report security incidents

## Feedback and Improvements

Runbooks are living documents. To suggest improvements:

1. **Open an issue** describing the problem or gap
2. **Submit a pull request** with proposed changes
3. **Discuss in team meetings** for major structural changes
4. **Update after incidents** to capture new learnings

---

## Quick Reference

### Common Commands by Platform

#### Fly.io
```bash
fly deploy                    # Deploy app
fly scale count 3             # Scale to 3 instances
fly logs                      # View logs
fly ssh console               # SSH into machine
```

#### AWS (ECS)
```bash
aws ecs update-service --cluster my-cluster --service my-service --desired-count 3
aws logs tail /ecs/my-app --follow
aws ecs execute-command --cluster my-cluster --task <task-id> --interactive --command "/bin/sh"
```

#### GCP (Cloud Run)
```bash
gcloud run deploy my-app --image <image-url> --region us-central1
gcloud run services update my-app --min-instances 1 --max-instances 10 --region us-central1
gcloud run services logs tail my-app --region us-central1
```

#### Kubernetes
```bash
kubectl apply -f deployment.yaml                    # Deploy
kubectl scale deployment my-app --replicas=3        # Scale
kubectl logs -l app=my-app -f                       # Logs
kubectl exec -it <pod-name> -- /bin/sh              # SSH
```

---

**Remember:** When in doubt, consult the runbook. When the runbook is wrong, fix it.
