# Stage 7: Policy & Compliance Gates

> **AI Attribution Block**: Developed with AI-assisted research. All specifications reviewed and validated by Nihal N.

## Overview

The Policy & Compliance Gates stage is the final checkpoint before deployment. It enforces automated regulatory compliance through OPA/Kyverno policies, verifies image provenance via Cosign, and ensures segregation of duties. This stage codifies RBI Master Direction, PCI-DSS v4.0, and internal governance requirements as machine-executable policies.

## Tool & Version

| Component | Specification |
|-----------|--------------|
| Policy Engine | OPA (Open Policy Agent) 0.62+ with Rego |
| K8s Policy Engine | Kyverno 1.11+ |
| Image Verification | Cosign 2.x |
| IaC Scanning | Checkov 3.x |
| Policy Testing | OPA test framework + conftest |

## Configuration

### OPA Policy Library

```
policies/
├── opa/
│   ├── no-privileged-containers.rego
│   ├── resource-limits-required.rego
│   ├── image-signing-required.rego
│   ├── network-policy-required.rego
│   ├── tls-enforcement.rego
│   ├── pii-encryption-required.rego
│   └── rbac-segregation.rego
└── kyverno/
    ├── require-labels.yaml
    ├── restrict-image-registries.yaml
    ├── require-probes.yaml
    └── disallow-default-namespace.yaml
```

### Policy Execution

```bash
# Run OPA policy checks against Kubernetes manifests
conftest test pipeline/helm/novapay/templates/ \
  --policy pipeline/policies/opa/ \
  --output json \
  --all-namespaces

# Run Kyverno policy checks in CLI mode
kyverno apply pipeline/policies/kyverno/ \
  --resource pipeline/helm/novapay/templates/ \
  --output json

# Verify image signature
cosign verify \
  --key cosign.pub \
  artifactory.novapay.internal/docker-local/novapay-app:${VERSION}

# Run Checkov for IaC compliance
checkov -d pipeline/terraform/ \
  --framework terraform \
  --output json \
  --compact
```

## Quality Gate

| Check | Threshold | Enforcement |
|-------|-----------|-------------|
| OPA policies | 100% pass rate | Hard block |
| Kyverno policies | 100% pass rate | Hard block |
| Image signature verification | Valid signature | Hard block |
| IaC compliance (Checkov) | No HIGH/CRITICAL findings | Hard block |
| Segregation of duties | Deployer ≠ Code author | Hard block |
| Deployment window | Not in blackout period | Hard block |

## Policy Descriptions

| Policy | Enforcement | RBI/PCI-DSS Mapping |
|--------|------------|---------------------|
| No privileged containers | All containers must run as non-root, no privileged mode | PCI-DSS 6.2 |
| Resource limits required | CPU and memory limits set on all containers | RBI 4.2 |
| Image signing required | Only Cosign-signed images from approved registry | RBI 5.4, PCI-DSS 6.3 |
| Network policy required | Every namespace must have a NetworkPolicy | PCI-DSS 6.4 |
| TLS 1.3 enforcement | All ingress must use TLS 1.3+, no weak ciphers | RBI 5.4 |
| PII encryption required | Volumes with PII data must use encrypted storage class | RBI 5.4 |
| RBAC segregation | Deploy role cannot be held by code author | RBI 4.3, PCI-DSS 6.5 |
| Required labels | All resources must have `app`, `version`, `owner`, `compliance-tier` labels | RBI 6.1 |
| Approved registries only | Images only from `artifactory.novapay.internal` | PCI-DSS 6.3 |
| Health probes required | All deployments must have liveness, readiness, and startup probes | RBI 6.3 |

## Segregation of Duties Enforcement

```yaml
# The deployer must NOT be the code author
segregation_check:
  rule: "deploy_approver != pr_author AND deploy_approver != pr_merger"
  enforcement: "hard_block"
  exception: "emergency_hotfix with CTO + CISO dual approval"
  audit_log:
    fields: [pr_author, pr_reviewers, pr_merger, deploy_approver, timestamp]
```

## Failure Modes & Remediation

| Failure | Cause | Remediation |
|---------|-------|-------------|
| OPA policy violation | Non-compliant K8s manifest | Fix manifest to meet policy requirements |
| Unsigned image | Image not signed by Cosign | Re-sign image in build stage |
| SoD violation | Same person authored and deploying | Different team member must approve deployment |
| Blackout window | Deployment attempted during peak hours | Wait for approved deployment window |
| IaC violation | Terraform resource non-compliant | Fix Terraform configuration |

## Exception Process (Dual Approval Override)

1. Engineer requests policy override with justification
2. Two approvers required (different from requester): Tech Lead + Security Champion
3. Override logged with full audit trail (who, what, when, why)
4. Override valid for single deployment only (not persistent)
5. TRC notified of all overrides in weekly compliance report

## SLA Target

| Metric | Target |
|--------|--------|
| OPA policy evaluation | < 30 seconds |
| Kyverno policy check | < 30 seconds |
| Cosign verification | < 10 seconds |
| Checkov scan | < 3 minutes |
| Total stage duration | < 5 minutes |

## RBI/PCI-DSS Mapping

- **RBI Section 4.2**: Change management — automated policy gates before deployment
- **RBI Section 4.3**: Segregation of duties — RBAC-enforced deploy/develop separation
- **RBI Section 5.4**: Encryption — TLS and storage encryption verification
- **RBI Section 6.1**: Audit trails — immutable compliance evidence per deployment
- **PCI-DSS Req 6.5**: Change management — policy-as-code enforces controls
- **PCI-DSS Req 10.2**: Audit log recording — all gate decisions logged
