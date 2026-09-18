# NovaPay Digital Bank — Production Deployment Runbook

> **AI Attribution Block**: Developed with AI-assisted research. All procedures reviewed and validated by Nihal N.

> **Document Classification**: INTERNAL — SRE & Release Management Only
> **Last Updated**: 2026-08-22 | **Owner**: SRE Team | **Review Cycle**: Monthly

---

## Pre-Deployment Checklist (8 Items)

Complete ALL items before initiating deployment. Evidence required for each.

| # | Check | How to Verify | Evidence |
|---|-------|--------------|----------|
| 1 | ✅ All CI pipeline stages passed | GitHub Actions: all jobs green | Pipeline run URL |
| 2 | ✅ SAST: 0 Critical, ≤ 2 High | SonarQube dashboard | SonarQube report link |
| 3 | ✅ DAST: 0 Critical/High (OWASP Top 10) | OWASP ZAP report | ZAP scan report JSON |
| 4 | ✅ Dependency scan: 0 Critical CVE | Trivy report | Trivy scan output |
| 5 | ✅ Deployment window verified | Check blackout calendar | Screenshot of calendar check |
| 6 | ✅ On-call engineer confirmed available | Slack message from on-call | Slack thread link |
| 7 | ✅ Dual approval obtained (RM + SRE Lead) | GitHub deployment review | GitHub review approvals |
| 8 | ✅ Database migration tested in pre-prod | Pre-prod migration log | Migration execution log |

---

## Deployment Execution Procedure

### Step 1: Verify Pre-Conditions

```bash
# 1.1 Check current production health
kubectl get pods -n novapay-prod -o wide
kubectl top pods -n novapay-prod

# 1.2 Check current version
kubectl get deployment novapay-app -n novapay-prod -o jsonpath='{.spec.template.spec.containers[0].image}'

# 1.3 Verify ArgoCD sync status
argocd app get novapay-production --grpc-web

# 1.4 Check blackout calendar
curl -s https://deploy-calendar.novapay.internal/api/v1/check | jq '.deployable'
# Expected: true
# If false → STOP. Do NOT proceed.
```

**Decision**: If ANY pre-condition fails → **STOP deployment**. Notify Release Manager.

### Step 2: Create Change Record

```bash
# Create deployment record in change management system
curl -X POST https://changes.novapay.internal/api/v1/changes \
  -H "Authorization: Bearer ${CHANGE_TOKEN}" \
  -d '{
    "type": "standard",
    "service": "novapay-app",
    "from_version": "'$(kubectl get deployment novapay-app -n novapay-prod -o jsonpath='{.spec.template.spec.containers[0].image}')'",
    "to_version": "novapay-app:'"${NEW_VERSION}"'",
    "deployer": "'$(whoami)'",
    "approvals": ["rm_approval_id", "sre_approval_id"]
  }'
```

### Step 3: Execute Database Migration (If Required)

```bash
# 3.1 Run expand phase migration
flyway -url=jdbc:postgresql://prod-db:5432/novapay \
  -user=${DB_USER} -password=${DB_PASSWORD} \
  migrate -target=${EXPAND_VERSION}

# 3.2 Verify migration success
flyway -url=jdbc:postgresql://prod-db:5432/novapay \
  -user=${DB_USER} -password=${DB_PASSWORD} \
  info

# 3.3 Monitor database latency during migration
# Watch Grafana dashboard: NovaPay Database Performance
# ABORT if query latency increases > 20%
```

**Decision**: If migration fails → **Rollback migration** using rollback SQL. **STOP deployment**.

### Step 4: Initiate Canary Deployment

```bash
# 4.1 Update Argo Rollouts with new image
kubectl argo rollouts set image novapay-app \
  novapay-app=artifactory.novapay.internal/docker-local/novapay-app:${NEW_VERSION} \
  -n novapay-prod

# 4.2 Watch canary progression
kubectl argo rollouts get rollout novapay-app -n novapay-prod --watch

# 4.3 Monitor canary metrics (open in browser)
echo "Grafana: https://grafana.novapay.internal/d/canary-analysis"
```

### Step 5: Monitor Canary Phases

| Phase | Traffic | Duration | Watch For |
|-------|---------|----------|-----------|
| Phase 1 | 2% | 15 min | Error rate < 0.1%, p99 < 200ms |
| Phase 2 | 10% | 30 min | Error rate < 0.05%, no critical alerts |
| Phase 3 | 50% | 60 min | All SLOs met |
| Phase 4 | 100% | 24hr bake | Complete SLO compliance |

```bash
# Check canary analysis status
kubectl argo rollouts status novapay-app -n novapay-prod
```

**Decision at each phase**:
- ✅ Metrics healthy → Auto-promote to next phase
- ❌ Metrics degraded → **Immediate rollback** (see Rollback Procedure below)

### Step 6: Post-Deployment Verification

```bash
# 6.1 Run smoke tests
./scripts/smoke-test.sh --env production --timeout 60

# 6.2 Verify all pods running new version
kubectl get pods -n novapay-prod -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' | sort | uniq -c

# 6.3 Check synthetic transactions
curl -s https://monitoring.novapay.internal/api/v1/synthetic/status | jq '.success_rate'
# Expected: 1.0 (100%)

# 6.4 Verify DORA metrics
echo "Lead time: $(date -d @$(($(date +%s) - $(git log -1 --format=%ct ${COMMIT_SHA}))) +%H:%M:%S)"
```

**Decision**: If ANY verification fails → **Execute rollback immediately**.

### Step 7: Close Change Record

```bash
# Mark deployment as successful
curl -X PATCH https://changes.novapay.internal/api/v1/changes/${CHANGE_ID} \
  -d '{"status": "completed", "outcome": "success"}'
```

### Step 8: Notify Stakeholders

```
DEPLOYMENT COMPLETE ✅

Service: NovaPay App
Version: v2.14.3
Environment: Production
Deployed by: [Name] (approved by: [RM Name], [SRE Name])
Duration: [X] minutes
Status: All smoke tests passed, metrics healthy

Dashboard: https://grafana.novapay.internal/d/novapay-prod
```

---

## Rollback Procedure

### Immediate Rollback (< 60 seconds)

```bash
# 1. Abort current rollout
kubectl argo rollouts abort novapay-app -n novapay-prod

# 2. Undo to previous version
kubectl argo rollouts undo novapay-app -n novapay-prod

# 3. Verify rollback
kubectl argo rollouts status novapay-app -n novapay-prod
kubectl get pods -n novapay-prod

# 4. Run smoke tests on restored version
./scripts/smoke-test.sh --env production --timeout 60

# 5. Notify
# Use incident communication template (see incident-playbook.md)
```

### Database Migration Rollback

```bash
# Only for EXPAND phase (CONTRACT is irreversible)
flyway -url=jdbc:postgresql://prod-db:5432/novapay \
  -user=${DB_USER} -password=${DB_PASSWORD} \
  undo -target=${PRE_MIGRATION_VERSION}
```

---

## Emergency Contacts

| Role | Name | Phone | Slack |
|------|------|-------|-------|
| SRE Lead | On-call | PagerDuty | @sre-oncall |
| Release Manager | On-call | PagerDuty | @release-manager |
| DBA | On-call | PagerDuty | @dba-oncall |
| VP Engineering | Arjun Singh | Escalation | @arjun.singh |
| CISO | Kavitha Rao | Escalation | @kavitha.rao |
