# Stage 3: Static Analysis & SAST

> **AI Attribution Block**: Developed with AI-assisted research. All specifications reviewed and validated by Nihal N.

## Overview

The Static Analysis & SAST stage performs automated source code analysis to detect security vulnerabilities, code smells, and quality issues before any code reaches runtime. For NovaPay, custom banking-specific rules detect PII mishandling, weak encryption usage, and SQL injection patterns.

## Tool & Version

| Component | Specification |
|-----------|--------------|
| Primary Tool | SonarQube 10.x (Community/Developer Edition) |
| Scanner | SonarScanner for Gradle |
| Quality Profile | Custom "NovaPay Banking" profile |
| Language | Java 21 |
| Integration | GitHub PR decoration via SonarQube plugin |

## Configuration

### SonarQube Quality Profile — NovaPay Banking

Custom rules added on top of the default "Sonar way" profile:

```properties
# sonar-project.properties
sonar.projectKey=novapay-digital-bank
sonar.projectName=NovaPay Digital Bank
sonar.sources=src/main/java
sonar.tests=src/test/java
sonar.java.binaries=build/classes
sonar.java.test.binaries=build/test-classes
sonar.coverage.jacoco.xmlReportPaths=build/reports/jacoco/test/jacocoTestReport.xml
sonar.qualitygate.wait=true
```

### Custom Banking Rules

| Rule ID | Description | Severity |
|---------|-------------|----------|
| NP-SEC-001 | PII fields (Aadhaar, PAN, email, phone) must use encryption helpers | Critical |
| NP-SEC-002 | Direct SQL string concatenation detected (SQL injection risk) | Critical |
| NP-SEC-003 | Hardcoded credentials or API keys in source | Critical |
| NP-SEC-004 | Weak encryption algorithm (DES, MD5, SHA-1) usage | Critical |
| NP-SEC-005 | Logging of sensitive financial data (account numbers, balances) | High |
| NP-SEC-006 | Missing input validation on API endpoints | High |
| NP-SEC-007 | Unencrypted HTTP endpoints (non-TLS) | High |
| NP-SEC-008 | Missing audit logging for financial transactions | Medium |

## Quality Gate

| Check | Threshold | Enforcement |
|-------|-----------|-------------|
| Critical vulnerabilities | 0 (zero tolerance) | Hard block |
| High vulnerabilities | ≤ 2 | Hard block |
| New code coverage | ≥ 80% | Hard block |
| Technical debt ratio (new code) | ≤ 5% | Soft warning |
| Code duplication (new code) | ≤ 3% | Soft warning |
| Security hotspots reviewed | 100% | Soft warning |

### Trend-Based Gating

Beyond absolute thresholds, the pipeline monitors **trends**:
- If total technical debt **increases** by more than 2 hours in a single PR → warning
- If security hotspot count **increases** by more than 5 in a single PR → manual review required

## Failure Modes & Remediation

| Failure | Cause | Remediation |
|---------|-------|-------------|
| Critical vulnerability detected | Insecure code pattern | Fix vulnerability, CISO approval within 24h for exception |
| High vulnerability count exceeded | Multiple security issues | Address top-severity issues first |
| Coverage below threshold | Insufficient test coverage | Write unit tests for uncovered code paths |
| SonarQube unavailable | Infrastructure issue | Retry 3 times; if persistent, pipeline pauses with alert |
| False positive | Scanner misidentification | Mark as false positive in SonarQube with justification |

## Exception Process

1. Developer marks finding as "won't fix" with justification
2. Security champion reviews within 4 hours
3. CISO approves exception within 24 hours
4. Exception auto-expires after 90 days (must be re-reviewed)
5. All exceptions logged in immutable audit trail

## SLA Target

| Metric | Target |
|--------|--------|
| Scan duration | < 15 minutes |
| PR decoration | < 2 minutes after scan |
| False positive rate | < 5% |

## RBI/PCI-DSS Mapping

- **RBI Section 5.1**: Vulnerability assessment performed regularly — SAST runs on every commit
- **PCI-DSS Req 6.2**: Bespoke software security — automated source code analysis
- **PCI-DSS Req 6.3**: Security vulnerabilities identified and addressed
