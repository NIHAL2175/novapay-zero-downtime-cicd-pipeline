# ERRATA — Deliberate Errors Found & Corrected

> **AI Attribution Block**: This document was developed with AI-assisted research and analysis. All error identifications were reviewed and validated by Nihal N. AI tools used: GitHub Copilot, ChatGPT (research assistance).

The project assessment document states it contains **exactly THREE (3) deliberate technical errors** — one in Part A, one in Part C, and one in Part D. Below are the identified errors, their corrections, and the reasoning behind each finding.

---

## Error 1: Part A — TLS Version Requirement in Policy Gate (Section A4.1)

### Location
**Section A4.1 — RBI Master Direction on IT Risk Mapping Table** (Page 8)

The mapping table for RBI Section 5.4 states:
> *"Encryption of data in transit and at rest → Policy gate: TLS 1.3 + encryption verification"*

### The Error
The policy gate specifies **TLS 1.3** as the mandatory requirement. However, PCI-DSS v4.0 Requirement 4.2.1 mandates **TLS 1.2** as the minimum acceptable version for data in transit. While TLS 1.3 is recommended and offers improved security, the regulatory baseline specified by PCI-DSS v4.0 is TLS 1.2. Setting the compliance gate to enforce TLS 1.3 exclusively would cause the gate to reject connections from legitimate banking partners and payment processors that still use TLS 1.2 — which is fully compliant with both RBI and PCI-DSS standards.

### Correction
The policy gate should read: **"TLS 1.2 minimum (TLS 1.3 preferred) + encryption verification"**

The OPA/Kyverno policy should accept TLS 1.2 and above:
```rego
deny[msg] {
    input.request.object.spec.tls.minVersion
    version := input.request.object.spec.tls.minVersion
    not version_acceptable(version)
    msg := sprintf("Minimum TLS version must be 1.2 or higher, found: %v", [version])
}

version_acceptable(v) { v == "TLSv1.2" }
version_acceptable(v) { v == "TLSv1.3" }
```

### Impact
Without this correction, the compliance gate would create false positive failures for valid TLS 1.2 connections, potentially blocking legitimate banking integrations and violating the principle of aligning automated gates to actual regulatory requirements.

---

## Error 2: Part C — Cloudflare Outage Duration (Case Study 3, Page 28)

### Location
**Case Study 3: Cloudflare Global Outage** (Page 28)

The case study header states:
> *"causing Cloudflare to drop approximately 50% of global HTTP traffic for 27 minutes"*

However, the NOTE at the end of the case study explicitly calls out:
> *"This case study contains a deliberate error in Part C. The original version of this document states the outage lasted 21 minutes. The actual duration was 27 minutes."*

### The Error
The document contradicts itself. The main body text uses the **correct** duration (27 minutes), but the assessment document explicitly states the **deliberate error** is that an "original version" states 21 minutes while the actual duration was 27 minutes. This is the Part C error designed for students to identify.

### Correction
The Cloudflare outage on **July 2, 2019** lasted approximately **27 minutes** (from 13:42 UTC to 14:09 UTC), during which approximately 50% of global HTTP traffic was dropped.

### Verification Source
Cloudflare's official post-mortem blog post: *"Cloudflare outage on July 2, 2019"* confirms the 27-minute duration. The incident was caused by a misconfigured WAF regex rule (`(?:(?:\"|'|\]|\}|\\|\/|=|\(|[^\x00-\x1f])\s)`) that triggered catastrophic CPU exhaustion across all edge servers.

---

## Error 3: Part D — GitHub Actions Workflow Reference Uses Incorrect Action Name (Appendix, Page 49–51)

### Location
**Appendix: GitHub Actions Workflow Reference** (Pages 49–51)

The reference CI pipeline and reusable SAST workflow both use:
```yaml
- name: SonarQube Scan
  uses: sonarqube-quality-gate-action@v1
```

### The Error
The action reference `sonarqube-quality-gate-action@v1` is **incorrect and does not exist** as a valid GitHub Action. The correct action is published by SonarSource under the organisation namespace:

- **SonarQube Quality Gate Check**: `sonarsource/sonarqube-quality-gate-action@v1` (checks quality gate status)
- **SonarQube Scan Action**: `sonarsource/sonarqube-scan-action@v2` (performs the actual scan)

The reference conflates two separate actions (scanning and quality gate checking) into a single non-existent action reference without the required organisation prefix.

### Correction
The pipeline should use two separate steps:
```yaml
- name: SonarQube Scan
  uses: sonarsource/sonarqube-scan-action@v2
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
  with:
    projectBaseDir: .
    args: >
      -Dsonar.projectKey=novapay-digital-bank
      -Dsonar.java.binaries=build/classes

- name: SonarQube Quality Gate Check
  uses: sonarsource/sonarqube-quality-gate-action@v1
  timeout-minutes: 5
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

### Impact
A pipeline referencing the incorrect action name would fail at the SAST stage with an "Action not found" error, completely blocking the CI pipeline. This is a critical error in a reference implementation meant to be customised for production use.

---

## Summary

| # | Part | Error Location | Error Description | Correction |
|---|------|---------------|-------------------|------------|
| 1 | Part A | Section A4.1, Page 8 | TLS 1.3 mandated instead of TLS 1.2 minimum | Change to TLS 1.2 minimum (1.3 preferred) |
| 2 | Part C | Case Study 3, Page 28 | Outage duration stated as 21 minutes | Correct duration is 27 minutes |
| 3 | Part D | Appendix, Pages 49–51 | Invalid action `sonarqube-quality-gate-action@v1` | Correct: `sonarsource/sonarqube-scan-action@v2` + `sonarsource/sonarqube-quality-gate-action@v1` |
