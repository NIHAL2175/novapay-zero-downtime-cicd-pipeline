# Stage 6: Dynamic Analysis & DAST

> **AI Attribution Block**: Developed with AI-assisted research. All specifications reviewed and validated by Nihal N.

## Overview

The DAST stage performs runtime security scanning against the deployed application in the staging environment. OWASP ZAP runs authenticated scans against NovaPay's API endpoints to detect vulnerabilities that are only visible at runtime — such as authentication bypasses, session management flaws, and injection attacks.

## Tool & Version

| Component | Specification |
|-----------|--------------|
| Scanner | OWASP ZAP 2.14+ |
| Scan Mode | Active + Passive (authenticated) |
| API Input | OpenAPI/Swagger spec |
| Report Format | JSON + HTML |
| Baseline | OWASP Top 10 (2021) |

## Configuration

### OWASP ZAP Scan Configuration

```yaml
# zap-config.yaml
env:
  contexts:
    - name: "NovaPay Banking API"
      urls:
        - "https://staging.novapay.internal"
      includePaths:
        - "https://staging.novapay.internal/api/.*"
      excludePaths:
        - "https://staging.novapay.internal/actuator/.*"
      authentication:
        method: "json"
        parameters:
          loginUrl: "https://staging.novapay.internal/api/v1/auth/login"
          loginRequestData: '{"username":"{%username%}","password":"{%password%}"}'
        verification:
          method: "response"
          loggedInRegex: "\\Qaccess_token\\E"
      users:
        - name: "test-user"
          credentials:
            username: "${ZAP_TEST_USERNAME}"
            password: "${ZAP_TEST_PASSWORD}"

  scanPolicy:
    name: "NovaPay Banking Policy"
    attackStrength: "MEDIUM"
    alertThreshold: "LOW"
    rules:
      # SQL Injection
      - id: 40018
        attackStrength: "HIGH"
        alertThreshold: "LOW"
      # Cross-Site Scripting
      - id: 40012
        attackStrength: "HIGH"
        alertThreshold: "LOW"
      # Authentication bypass
      - id: 10101
        attackStrength: "HIGH"
        alertThreshold: "LOW"
```

### API-Specific Scanning

```bash
# Import OpenAPI spec for comprehensive API scanning
zap-cli openapi import \
  --url https://staging.novapay.internal/v3/api-docs \
  --context "NovaPay Banking API"

# Run active scan with authentication
zap-cli active-scan \
  --context "NovaPay Banking API" \
  --user "test-user" \
  --recurse \
  --policy "NovaPay Banking Policy"
```

## Quality Gate

| Check | Threshold | Enforcement |
|-------|-----------|-------------|
| Critical findings (OWASP Top 10) | 0 | Hard block |
| High findings (OWASP Top 10) | 0 | Hard block |
| Medium findings | ≤ 5 | Soft warning |
| Low/Informational | Report only | Log |
| Scan completion | All endpoints covered | Hard block |

### OWASP Top 10 Severity Mapping

| OWASP Category | ZAP Alert IDs | Severity | Action |
|----------------|---------------|----------|--------|
| A01: Broken Access Control | 10101, 10102 | Critical | Block |
| A02: Cryptographic Failures | 10040, 10041 | Critical | Block |
| A03: Injection | 40018, 40019, 40012 | Critical | Block |
| A04: Insecure Design | 10045 | High | Block |
| A05: Security Misconfiguration | 10035, 10036 | High | Block |
| A06: Vulnerable Components | 10054 | High | Block |
| A07: Auth Failures | 10055, 10056 | Critical | Block |
| A08: Data Integrity Failures | 10060 | High | Block |
| A09: Logging Failures | 10057 | Medium | Warn |
| A10: SSRF | 40046 | High | Block |

## False Positive Management

```yaml
# zap-false-positives.yaml
falsePositives:
  - alertRef: 10035
    url: "https://staging.novapay.internal/api/v1/health"
    justification: "Health endpoint intentionally returns server info"
    approvedBy: "kavitha.rao@novapay.com"
    expiresAt: "2027-02-22"
```

- False positives must be justified and approved by a security team member
- Each false positive entry expires after 180 days and must be re-reviewed
- All false positive decisions are logged in the audit trail

## Failure Modes & Remediation

| Failure | Cause | Remediation |
|---------|-------|-------------|
| Critical finding | Active vulnerability in running app | Fix vulnerability, redeploy to staging |
| Scan timeout | Application unresponsive | Check staging env health, increase timeout |
| Authentication failure | Test credentials expired | Rotate test credentials, update vault |
| Incomplete scan | Endpoints not reachable | Verify API spec is up-to-date |
| False positive | Scanner misidentification | Document in zap-false-positives.yaml |

## Exception Process

1. Security engineer triages finding and confirms it's a true positive
2. If exception needed: Risk acceptance form submitted with compensating controls
3. CISO + Head of Compliance dual approval required
4. Exception logged with TRC notification
5. Exception auto-expires after 30 days (Critical) or 90 days (High)

## SLA Target

| Metric | Target |
|--------|--------|
| Passive scan | < 5 minutes |
| Active scan | < 20 minutes |
| Report generation | < 2 minutes |
| Total stage duration | < 25 minutes |

## RBI/PCI-DSS Mapping

- **RBI Section 5.1**: Vulnerability assessment — runtime scanning on every deployment
- **PCI-DSS Req 6.4**: Public-facing web application protection — DAST scanning
- **PCI-DSS Req 11.3**: Penetration testing — automated DAST integrated into pipeline
