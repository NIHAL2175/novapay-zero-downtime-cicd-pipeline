# Incident Simulation Response — Friday 5:07 PM IST

> **AI Attribution Block**: This incident simulation response was developed with AI-assisted analysis. All decisions, timestamps, and pipeline gap analysis were reviewed by Nihal N.

## Scenario Recap

**Date**: Friday, 5:07 PM IST  
**Context**: A developer pushed a "critical hotfix" that **bypassed staging**. The canary deployment has been running for 8 minutes when three alerts fire simultaneously:

| Alert | Metric | Threshold | Severity |
|-------|--------|-----------|----------|
| HTTP 500 error rate at 12% | Error rate > 5% for 60s | 5% | 🔴 CRITICAL |
| PostgreSQL connection pool exhaustion | Connection pool at 100% | 90% | 🟠 HIGH |
| Payment gateway timeout rate at 35% | Timeout rate > 10% | 10% | 🔴 CRITICAL |

---

## Incident Response Timeline

### T+0:00 (17:07:00 IST) — Alert Fires

**Action**: PagerDuty triggers SEV-1 alert to SRE on-call (primary) and SRE Lead (secondary).

- Three simultaneous alerts detected by Prometheus Alertmanager
- Alert routing: `severity=critical` → PagerDuty escalation → phone call + Slack #novapay-incidents
- **Automated action**: Category A rollback trigger activated — HTTP 5xx rate 12% exceeds 5% threshold

**Decision**: Per the rollback specification (Deliverable 6, Category A), the 12% error rate triggers **immediate automated rollback** with zero human intervention.

### T+0:15 (17:07:15 IST) — Automated Rollback Initiated

**Action**: Automated rollback system executes.

```
[Step 1/8] DETECT — Rollback triggered
  Trigger: HTTP 5xx rate 12% > 5% threshold (Category A - Immediate)
  Category: A
[Step 2/8] CORRELATE — Identifying affected pods
  Canary pods: novapay-app-canary-7b4f9 (CrashLoopBackOff)
  Stable pods: novapay-app-stable-* (healthy)
```

- ArgoCD auto-sync paused
- Istio VirtualService updated: canary traffic weight set to 0%
- All traffic routed to stable version (100%)

### T+0:30 (17:07:30 IST) — On-Call Engineer Acknowledges

**Action**: SRE on-call acknowledges PagerDuty alert.

- Opens Grafana Engineering Dashboard — confirms error rate spike
- Notes: automated rollback already in progress
- **Decision**: Classify as **SEV-1** (complete service degradation for canary users + downstream payment gateway impact)

### T+0:45 (17:07:45 IST) — Rollback Complete

**Action**: Istio confirms 100% traffic on stable version.

```
[Step 5/8] VERIFY — Rollback verification
  All pods running stable version: novapay-app:2.14.2+sha.e4f5g6h
  Error rate: 0.02% (nominal)
  PostgreSQL connections: 45/100 (normal)
  Payment gateway timeout: 0.1% (normal)
```

**Total rollback time**: 30 seconds (well within Category A < 60s target)

### T+1:00 (17:08:00 IST) — Initial Communication Sent

**Action**: SRE on-call sends SEV-1 initial acknowledgement.

**Internal Slack (#novapay-incidents)**:
> 🔴 **SEV-1 INCIDENT — INC-20260824170700**
> **Status**: Mitigated — automated rollback complete
> **Impact**: ~8 minutes of elevated errors for canary traffic (~2% of users)
> **Cause**: Hotfix deployment bypassed staging, caused connection pool exhaustion
> **Next update**: 17:30 IST

### T+3:00 (17:10:00 IST) — Triage & Root Cause Investigation

**Action**: SRE on-call + SRE Lead investigate root cause.

**Findings**:
1. Developer pushed hotfix directly to `hotfix/fix-payment-timeout` branch
2. Hotfix was merged to `main` with emergency approval — **bypassing staging environment**
3. The hotfix contained a database query change that removed connection pooling limits
4. Under production load, the query spawned unlimited connections → pool exhaustion
5. Pool exhaustion caused cascading failures to downstream payment gateway

**Root cause**: The hotfix bypassed the integration testing stage (Stage 5) where database connection testing would have caught the pooling issue.

### T+5:00 (17:12:00 IST) — Stakeholder Notification

**Action**: VP Engineering and CTO briefed.

> **Summary**: Automated rollback resolved a canary deployment incident in 30 seconds. A hotfix that bypassed staging caused database connection pool exhaustion. The pipeline's Category A rollback trigger (5xx > 5%) detected and resolved the issue before it affected more than 2% of users.

### T+23:00 (17:30:00 IST) — Status Update

**Action**: SRE on-call sends update.

**Internal Slack (#novapay-incidents)**:
> 🟢 **SEV-1 UPDATE — INC-20260824170700**
> **Status**: Resolved
> **Duration**: 30 seconds (automated rollback)
> **User impact**: <2% of users experienced errors for ~8 minutes during canary phase
> **Root cause**: Hotfix bypassed staging → untested DB connection change → pool exhaustion
> **Post-mortem**: Scheduled for Monday 10:00 AM IST

---

## Pipeline Gap Analysis

### Which gate was bypassed?

The hotfix **bypassed Stage 5 (Integration & Contract Testing)**, which includes database integration tests with PostgreSQL test containers. The integration test suite would have detected the connection pooling issue because it tests against a real PostgreSQL instance with connection limits configured.

### Why did the pipeline allow this?

The current emergency hotfix path allows merging to `main` with expedited review, but it still requires all pipeline stages to pass. In this scenario, the **developer's emergency approval bypassed the staging environment entirely**, deploying directly from a PR merge to canary without the integration test stage completing.

### What gate was missing?

1. **Staging bypass guard**: The pipeline should include a hard block that prevents any deployment to production (even canary) without successful staging deployment. Currently, the dual approval gate (Release Manager + SRE Lead) can override this — but the override should require **CISO approval** for any deployment that skips staging.

2. **Connection pool smoke test**: The post-deployment smoke test suite should include a database connection pool utilisation check. The current smoke tests verify HTTP health and basic API responses but do not validate database connection behaviour under load.

3. **Hotfix audit trail**: While the hotfix followed the expedited path, there should be an automated compliance record indicating which stages were bypassed and who approved the bypass. This is required for RBI Section 4.2 (change management traceability).

### Corrective Actions

| # | Action | Owner | Deadline |
|---|--------|-------|----------|
| 1 | Add mandatory staging gate — no override without CISO approval | SRE Lead | 48 hours |
| 2 | Add connection pool smoke test to post-deployment verification | Dev Team | 1 week |
| 3 | Add hotfix bypass audit record to compliance gate | Platform Team | 1 week |
| 4 | Implement pre-merge connection pool load test | Dev Team | 2 weeks |
| 5 | Update incident playbook with DB connection pool runbook | SRE on-call | 48 hours |
