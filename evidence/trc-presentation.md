# TRC Presentation — NovaPay Digital Bank
## Zero-Downtime CI/CD Pipeline with Compliance Gates

> **AI Attribution Block**: This presentation was developed with AI-assisted research. All content reviewed by Nihal N.

> **Format**: This document is structured as a 20-slide presentation for the Technology Risk Committee. Each section marked with `---` represents a slide boundary. Convert to PDF using Marp, Google Slides, or PowerPoint for final submission.

---

### Slide 1: Title

# Zero-Downtime CI/CD Pipeline with Compliance Gates
## NovaPay Digital Bank — Technology Risk Committee Presentation

**Presented by**: Nihal N, DevOps Lead  
**Date**: August 2026  
**Classification**: Strictly Confidential

---

### Slide 2: Agenda

1. Current State Assessment
2. Proposed Solution Architecture
3. Eight-Stage Pipeline Design
4. Deployment Strategies (Blue-Green & Canary)
5. Compliance Gate Framework (RBI + PCI-DSS)
6. Zero-Downtime Database Migration
7. Observability & DORA Metrics
8. Risk Mitigation & Rollback Strategy
9. Implementation Timeline
10. Q&A

---

### Slide 3: Current State — The Problem

## NovaPay's Current State: Critical Gaps

| Metric | Current State | Industry Benchmark |
|--------|:---:|:---:|
| Deployment Frequency | 1x / 2 weeks | Multiple / day |
| Mean Time to Recovery | **4.5 hours** | **< 15 minutes** |
| Automated Compliance | **None** | Fully automated |
| RBI Non-Conformances | **17 open** | 0 |
| Observability | **Zero** | Full stack |
| Deployment Method | **Manual SSH** | CI/CD Pipeline |

**Risk**: 3 production incidents in Q4 2025 traced to untested code deployments.

---

### Slide 4: Current State — Business Impact

## Business Risk Quantification

- **Revenue risk**: Manual deployments → 2-week release cycles → losing market share to fintechs deploying daily
- **Regulatory risk**: 17 open RBI non-conformances → potential regulatory action, licence conditions
- **Operational risk**: 4.5-hour MTTR → extended outages during UPI peak hours (10AM-12PM, 5PM-8PM IST)
- **Compliance risk**: Zero automated scanning → no evidence trail for audits → PCI-DSS certification at risk

> **UPI context**: India processes 12B+ transactions/month. A 30-second outage during peak affects millions.

---

### Slide 5: Proposed Solution — Pipeline Overview

## Eight-Stage CI/CD Pipeline Architecture

```
Source → Build → SAST → Scanning → Integration → DAST → Compliance → Deploy
 (30s)   (12m)   (15m parallel)     (18m)        (25m)    (5m)       (30m)
```

**Key metrics achieved**:
- Commit to production: **< 2 hours** (vs current 2 weeks)
- MTTR: **< 15 minutes** (vs current 4.5 hours)
- Automated compliance: **6+ gates** (vs current 0)
- Availability target: **99.999%** (five nines)
- Parallelisation: **> 40%** of scanning stages

---

### Slide 6: Pipeline Architecture Diagram

## Pipeline Flow with Parallel Execution

Stages 3 (SAST) and 4 (Dependency/Container Scanning) execute **in parallel** after build, saving 10-15 minutes.

| Block | Stages | Duration |
|-------|--------|----------|
| Sequential | Stage 1: Source Control | 30s |
| Sequential | Stage 2: Build & Tests | 8-12 min |
| **Parallel** | **Stage 3 + Stage 4** | **10-15 min** |
| Sequential | Stage 5: Integration Tests | 12-18 min |
| Sequential | Stage 6: DAST | 15-25 min |
| Sequential | Stage 7: Compliance Gates | 3-5 min |
| Sequential | Stage 8: Deployment | 15-30 min |
| **Total** | | **63-106 min** |

---

### Slide 7: Security — SAST & DAST

## Automated Security Scanning

**SAST (Stage 3) — SonarQube 10.x**:
- Custom banking rules: PII handling, encryption usage, SQL injection patterns
- Thresholds: 0 Critical, ≤ 2 High, ≥ 80% code coverage
- On failure: Pipeline blocked, auto-ticket created

**DAST (Stage 6) — OWASP ZAP 2.14+**:
- Authenticated scanning with secure test credentials
- API-specific scanning with OpenAPI spec input
- Thresholds: 0 Critical/High from OWASP Top 10
- On failure: Pipeline blocked, risk acceptance form required

---

### Slide 8: Supply Chain Security

## Container Signing & SBOM

- **Trivy 0.50+**: Container image vulnerability scanning
  - 0 Critical CVE threshold (hard block)
  - Licence compliance: GPL/AGPL/SSPL blacklisted
- **Syft**: SBOM generation in CycloneDX format — archived per build
- **Cosign**: Image signing with cryptographic attestation
  - Kubernetes admission controller rejects **unsigned images**
- **SLSA Level 2**: Build provenance attestation

> Every container in production is signed, scanned, and has a complete Software Bill of Materials.

---

### Slide 9: Compliance Gate Framework

## 6+ Automated Compliance Gates

| Gate | Tool | Threshold | On Failure | RBI/PCI-DSS Mapping |
|------|------|-----------|------------|-------------------|
| SAST | SonarQube | 0 Critical, ≤2 High | Blocked | PCI-DSS 6.2 |
| DAST | OWASP ZAP | 0 Critical/High | Blocked | PCI-DSS 6.4, 11.3 |
| Dependency | Trivy | 0 Critical CVE | Blocked | PCI-DSS 6.3, RBI 5.1 |
| Licence | Trivy/FOSSA | No GPL/AGPL | Legal review | RBI 7.2 |
| Policy | OPA/Kyverno | All K8s policies pass | Rejected | RBI 4.2 |
| IaC | Checkov | No privileged containers | PR blocked | PCI-DSS 6.5 |

Each gate has: **precise thresholds**, **remediation guidance**, **exception workflow**, **audit trail**.

---

### Slide 10: RBI IT Risk Compliance Mapping

## Direct Mapping to RBI Master Direction

| RBI Section | Requirement | Pipeline Control |
|-------------|-------------|-----------------|
| 4.2 | Change management, testing, approval | CI/CD gates + dual approval + rollback |
| 4.3 | Segregation of duties | RBAC: developer ≠ deployer |
| 5.1 | Vulnerability assessment | SAST + DAST + dependency scan |
| 5.4 | Encryption in transit/at rest | TLS 1.2 minimum + KMS encryption |
| 6.1 | Comprehensive audit trails | Immutable pipeline audit log (JSON) |
| 6.3 | Incident management | Automated rollback + incident playbook |
| 7.2 | Third-party risk | SBOM + licence compliance gate |

> **Result**: Pipeline addresses all 17 open RBI non-conformances.

---

### Slide 11: Deployment Strategy — Blue-Green

## Blue-Green Zero-Downtime Deployment

- Two identical environments: `novapay-prod-blue` and `novapay-prod-green`
- Atomic traffic switch via **Istio VirtualService**
- Shared database layer (requires backward-compatible schema)
- Connection draining: 60s HTTP, 5 min payment settlement jobs
- Session management: **Redis cluster** (3 nodes) prevents session loss

**Rollback**: Instant — revert VirtualService to previous colour (< 5 seconds)

---

### Slide 12: Deployment Strategy — Canary

## Statistical Canary Progressive Rollout

| Phase | Traffic | Duration | Success Criteria |
|-------|---------|----------|-----------------|
| Canary | 1-2% | 15 min | Error rate < 0.1%, p99 < 200ms |
| Early Adopter | 5-10% | 30 min | Error rate < 0.05%, no critical alerts |
| Expansion | 25-50% | 60 min | All SLOs met, no degradation |
| Full Rollout | 100% | 24h bake | Complete SLO compliance |

**Statistical analysis**: Welch's t-test (latency), chi-squared (error rates), 95% confidence interval.

---

### Slide 13: Database Migration — Expand-Contract

## Zero-Downtime Database Migration for 100M+ Row Tables

1. **EXPAND**: Add new columns alongside existing (backward compatible)
2. **MIGRATE**: Batch backfill with throttling (100ms pause/batch, 1000 rows/batch)
3. **CONTRACT**: Remove old columns (separate deployment, DBA approval required)

**Key safeguards**:
- pgroll for online schema migration (no table-level locks)
- Abort if query latency increases > 20%
- Version compatibility matrix: App V(N-1) and V(N) coexist
- Each phase independently deployable and reversible (except CONTRACT)

---

### Slide 14: Rollback Strategy

## Three-Category Automated Rollback

| Category | Response Time | Triggers | Action |
|----------|:---:|---------|--------|
| **A — Immediate** | < 60s | 5xx > 5%, OOM, CrashLoopBackOff, DB pool exhaustion | **Auto-rollback, zero human intervention** |
| **B — Escalated** | < 15 min | p99 > 2x baseline, error budget burn > 10x | Alert on-call; auto-rollback if no response |
| **C — Manual** | Human decision | Gradual degradation, customer reports | Surface warnings for human judgment |

**8-step execution**: Detect → Correlate → Freeze → Rollback → Verify → Notify → Incident → Postmortem

---

### Slide 15: Observability & DORA Metrics

## DORA Elite Performance Targets

| Metric | Current | Target | Measurement |
|--------|:---:|:---:|---------|
| Deployment Frequency | 1x/2 weeks | Multiple/day | ArgoCD sync count |
| Lead Time | ~2 weeks | < 1 hour | Commit → prod timestamp diff |
| Change Failure Rate | Unknown | < 5% | Rollbacks / total deploys |
| MTTR | 4.5 hours | < 15 min | Detection → resolution |

**Stack**: Prometheus (metrics) + Grafana (dashboards) + Loki (logs) + OpenTelemetry (tracing)

---

### Slide 16: Grafana Dashboards

## Three-Tier Dashboard Strategy

| Dashboard | Audience | Key Panels | Refresh |
|-----------|----------|-----------|---------|
| **Engineering** | SRE, Dev | DORA metrics, pipeline health, latency, errors | 30s |
| **Management** | CTO, VP Eng | Deployment trends, cost/deploy, automation ratio | 5 min |
| **Regulatory** | Compliance, Auditor | Gate pass rates, CVE tracking, RBI compliance status | 1 hour |

> Grafana dashboard JSON exports included in the repository.

---

### Slide 17: Environment Promotion Workflow

## Four-Environment Model

```
Development → Staging → Pre-Production → Production
(auto)        (auto)     (manual gate)     (dual approval)
```

| Environment | Data | Access | Promotion Gate |
|-------------|------|--------|---------------|
| Development | Synthetic/mock | All developers | Automated (all tests pass) |
| Staging | Anonymised | Dev + QA | Automated (DAST + perf pass) |
| Pre-Production | Masked production | QA + Compliance | Tech Lead approval |
| Production | Real data | SRE + RM only | **Dual approval** (RM + SRE Lead) |

---

### Slide 18: Risk Mitigation Summary

## How Each Risk Is Mitigated

| Risk | Mitigation | Evidence |
|------|-----------|---------|
| Untested code in production | 8-stage pipeline with blocking gates | ci-pipeline.yml |
| Regulatory non-compliance | 6+ automated compliance gates with RBI mapping | compliance-gates.md |
| Deployment outage | Blue-green + canary with auto-rollback | deployment-strategies.md |
| Database migration failure | Expand-contract with version matrix | database-migration.md |
| Slow incident recovery | Automated rollback (< 60s) + incident playbook | rollback-specification.md |
| Audit trail gaps | Structured JSON audit records per deployment | compliance-audit.json |
| Insider threat | Segregation of duties (developer ≠ deployer) | RBAC in pipeline |

---

### Slide 19: Implementation Timeline

## 90-Day Rollout Plan

| Phase | Weeks | Deliverables |
|-------|-------|-------------|
| **Foundation** | 1-2 | GitHub Actions pipeline (Stages 1-4), branch protection, ArgoCD setup |
| **Security** | 3-4 | SAST/DAST integration, compliance gates, OPA policies |
| **Deployment** | 5-6 | Blue-green infrastructure, Istio VirtualService, canary analysis |
| **Compliance** | 7-8 | RBI mapping validation, audit trail implementation, TRC review |
| **Observability** | 9-10 | Prometheus/Grafana, alerting, DORA dashboards |
| **Hardening** | 11-12 | Incident simulation, runbook testing, security audit |
| **Go-Live** | 13 | Production cutover with parallel running |

**Quick win** (Week 1): Automated build + SAST scanning eliminates the highest-risk gap immediately.

---

### Slide 20: Recommendation & Next Steps

## TRC Approval Request

**Recommendation**: Approve the proposed CI/CD pipeline architecture for immediate implementation.

**Key outcomes upon approval**:
- ✅ Resolve all 17 RBI non-conformances within 90 days
- ✅ Reduce MTTR from 4.5 hours to < 15 minutes
- ✅ Enable multiple daily deployments (currently fortnightly)
- ✅ Achieve five-nines availability (99.999%)
- ✅ Automated compliance evidence for every production deployment

**Immediate next steps**:
1. TRC approval of pipeline architecture
2. Infrastructure provisioning (Week 1-2)
3. First automated deployment to staging (Week 3)
4. First canary production deployment (Week 8)

**Questions?**
