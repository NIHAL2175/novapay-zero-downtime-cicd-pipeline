# Post-Mortem Report — INC-20260824170700

> **AI Attribution Block**: This post-mortem report was developed with AI-assisted analysis. All findings and action items were reviewed by Nihal N.

## Incident Summary

| Field | Value |
|-------|-------|
| **Incident ID** | INC-20260824170700 |
| **Severity** | SEV-1 |
| **Date** | Friday, 24 August 2026 |
| **Duration** | 8 minutes (canary exposure), 30 seconds (automated rollback) |
| **Detection** | Automated (Prometheus alerting) |
| **Resolution** | Automated (Category A rollback) |
| **User Impact** | ~2% of users experienced HTTP 500 errors for ~8 minutes |
| **Financial Impact** | Estimated 340 failed payment transactions during canary exposure |
| **Root Cause** | Hotfix bypassed staging environment, contained untested DB connection change |

---

## Timeline

| Timestamp (IST) | Event |
|-----------------|-------|
| 16:45:00 | Developer opens PR for hotfix `fix-payment-timeout` |
| 16:50:00 | Emergency review approved by Tech Lead (staging bypass requested) |
| 16:55:00 | PR merged to `main` — CI pipeline triggered |
| 16:58:00 | Stages 1-4 pass (Source, Build, SAST, Scanning) |
| 17:00:00 | Stage 5 (Integration Tests) — **SKIPPED per emergency override** |
| 17:02:00 | Stages 6-7 pass (DAST ran against dev environment, Compliance gates pass) |
| 17:04:00 | Stage 8 — Canary deployment begins (2% traffic) |
| 17:07:00 | **ALERT**: HTTP 500 rate at 12%, PostgreSQL connection pool exhaustion, payment gateway timeouts at 35% |
| 17:07:15 | **Automated rollback initiated** (Category A trigger) |
| 17:07:30 | On-call SRE acknowledges alert |
| 17:07:45 | **Rollback complete** — all traffic on stable version |
| 17:08:00 | SEV-1 communication sent to #novapay-incidents |
| 17:10:00 | Root cause identified: unlimited DB connections in hotfix code |
| 17:30:00 | Incident marked as resolved |

---

## Root Cause Analysis

### Direct Cause
The hotfix modified the database query layer to address payment timeout issues. The change removed a connection pool size limit parameter, causing the application to open unlimited database connections under production traffic load. This exhausted the PostgreSQL connection pool (100 connections max via pgBouncer), which cascaded to:
1. HTTP 500 errors (12%) — application threads blocked waiting for DB connections
2. Payment gateway timeouts (35%) — payment processing queries unable to acquire connections
3. Connection pool exhaustion on primary PostgreSQL instance

### Contributing Factors

1. **Staging bypass**: The hotfix was deployed to production canary without passing through the staging environment, where integration tests with production-like database load would have caught the connection pool issue.

2. **Incomplete DAST coverage**: The DAST scan ran against the dev environment (which has minimal traffic), not staging. Under low traffic, the connection pool issue is invisible because the total connections never approach the limit.

3. **Friday afternoon deployment**: The deployment occurred during high-traffic hours (5 PM IST) and on a Friday, increasing both the blast radius and the risk of a weekend incident.

4. **Emergency override process**: The current emergency hotfix path allows bypassing staging with a single Tech Lead approval. This is insufficient for a SEV-1 risk deployment.

### What Went Right

1. **Automated rollback worked exactly as designed** — Category A trigger (5xx > 5% for 60s) detected the issue and initiated rollback within 15 seconds.
2. **Canary deployment limited blast radius** — only 2% of traffic was affected, preventing a full outage.
3. **Total recovery time: 30 seconds** — well within the < 60-second target for Category A incidents.
4. **Observability stack** detected the incident before any customer reported it.

### What Went Wrong

1. **Staging environment bypass** was approved with insufficient scrutiny.
2. **No connection pool specific monitoring** in the smoke test suite.
3. **Deployment blackout check did not flag** the Friday 5 PM window as high-risk (it warns but does not block).
4. **The integration test stage was the only gate** that would have caught this specific failure mode.

---

## Impact Assessment

| Metric | Value |
|--------|-------|
| Duration of degraded service | 8 minutes (canary only) |
| Users affected | ~2% of active users (~4,800 out of ~240,000 concurrent) |
| Failed transactions | ~340 payment transactions |
| Revenue impact | Estimated ₹2.1 lakh in failed transactions (recovered after retry) |
| SLA impact | 99.997% monthly availability maintained (within 99.999% budget) |
| Regulatory impact | None — incident duration < 30 minutes, no RBI notification required |

---

## Action Items

| # | Action Item | Priority | Owner | Deadline | Status |
|---|-------------|----------|-------|----------|--------|
| 1 | **Mandatory staging gate**: No production deployment without successful staging. Emergency bypass requires CISO + VP Engineering dual approval (not Tech Lead alone) | P0 | SRE Lead | 48 hours | 🔴 Open |
| 2 | **Connection pool smoke test**: Add DB connection utilisation check to post-deployment verification suite | P0 | Dev Team Lead | 1 week | 🔴 Open |
| 3 | **Upgrade blackout check**: Make Friday 5 PM a hard block (not warning) unless emergency-approved | P1 | Platform Team | 1 week | 🔴 Open |
| 4 | **Hotfix audit trail**: Auto-generate compliance record when any stage is bypassed, including bypasser identity and approver | P1 | Platform Team | 1 week | 🔴 Open |
| 5 | **Pre-merge load test**: Add connection pool load test to integration test suite, simulating 2x production connection count | P1 | Dev Team | 2 weeks | 🔴 Open |
| 6 | **Update incident playbook**: Add DB connection pool exhaustion runbook with pgBouncer diagnostic steps | P2 | SRE on-call | 48 hours | 🔴 Open |
| 7 | **DAST environment**: Ensure DAST scans run against staging (not dev) to test under realistic load conditions | P2 | Platform Team | 2 weeks | 🔴 Open |

---

## Lessons Learned

1. **Bypassing stages is always a risk** — the emergency hotfix path exists for genuine emergencies, but it must require higher-authority approval proportional to the stages being skipped.

2. **Canary deployments saved us** — without the 2% traffic split, this hotfix would have caused a full production outage affecting all ~240,000 concurrent users. The canary pattern reduced the blast radius by 98%.

3. **Automated rollback is the safety net** — the 30-second recovery time validates the Category A trigger design. The pipeline's rollback system performed exactly as specified.

4. **Observability must cover infrastructure, not just application** — the HTTP error rate alert caught the symptom, but a connection pool utilisation alert would have provided earlier warning (before 5xx errors manifested).

---

## Post-Mortem Attendees

| Name | Role |
|------|------|
| SRE On-Call Engineer | Incident Commander |
| SRE Lead | Escalation Manager |
| Developer (hotfix author) | Contributing Engineer |
| Tech Lead (approver) | Review Approver |
| VP Engineering | Executive Sponsor |

**Next review**: 30-day action item review — scheduled for 23 September 2026.
