# Stage 1: Source Control & Trigger

> **AI Attribution Block**: Developed with AI-assisted research. All specifications reviewed and validated by Nihal N.

## Overview

The Source Control & Trigger stage is the entry point of the NovaPay CI/CD pipeline. It validates that every code change meets the minimum governance requirements before any compute resources are consumed.

## Tool & Version

| Component | Specification |
|-----------|--------------|
| Platform | GitHub Enterprise |
| API Version | REST v3 / GraphQL v4 |
| Webhook Format | JSON payload |
| Authentication | GitHub App (preferred) or PAT |

## Configuration

### Trigger Events

```yaml
on:
  push:
    branches: [main, release/*, hotfix/*]
    paths-ignore:
      - '*.md'
      - 'docs/**'
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [staging, pre-prod, production]
```

### Branch Protection Rules

- **Required reviewers**: 2 (minimum), including 1 CODEOWNERS match
- **Stale review dismissal**: Enabled — new pushes invalidate previous approvals
- **Signed commits**: Mandatory (GPG or SSH key signature)
- **Status checks**: All CI stages must pass before merge
- **Admin enforcement**: Enabled — even admins cannot bypass rules
- **Force push**: Disabled on `main` and `release/*`
- **Deletion protection**: Enabled on `main`

### Monorepo Path-Based Triggering

NovaPay's microservices architecture uses path-based filtering:

```yaml
# Example: Only trigger payment-service pipeline when its code changes
paths:
  - 'services/payment-service/**'
  - 'shared/common-lib/**'
  - 'proto/payment/**'
```

## Quality Gate

| Check | Threshold | Enforcement |
|-------|-----------|-------------|
| Commit signature | Valid GPG/SSH signature | Hard block |
| Branch protection | All rules satisfied | Hard block |
| PR description | Non-empty, template followed | Soft warning |
| Linked issue | At least one linked Jira/GitHub issue | Soft warning |

## Failure Modes & Remediation

| Failure | Cause | Remediation |
|---------|-------|-------------|
| Unsigned commit | Developer hasn't configured GPG key | Guide: `git config --global commit.gpgsign true` |
| Branch protection bypass | Direct push to `main` | Rejected automatically by GitHub |
| Webhook delivery failure | Network timeout | GitHub retries up to 3 times with exponential backoff |
| Rate limiting | Excessive triggers | Implement debounce: ignore pushes within 5s of each other |

## Retry/Skip Logic

- **Retry**: Webhook failures are retried by GitHub (3 attempts, exponential backoff)
- **Skip**: Commits with `[skip ci]` or `[ci skip]` in the message bypass pipeline (disabled for `main` branch)
- **Debounce**: Multiple rapid pushes within 5 seconds are coalesced into a single pipeline run

## SLA Target

| Metric | Target |
|--------|--------|
| Trigger-to-pipeline-start | < 30 seconds |
| Webhook delivery reliability | > 99.9% |

## RBI/PCI-DSS Mapping

- **RBI Section 4.2**: Change management — signed commits provide auditable change records
- **RBI Section 4.3**: Segregation of duties — branch protection enforces review before merge
- **PCI-DSS Req 6.5**: Change management processes — all changes tracked via pull requests
