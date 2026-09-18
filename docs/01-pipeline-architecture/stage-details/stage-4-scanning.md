# Stage 4: Dependency & Container Scanning

> **AI Attribution Block**: Developed with AI-assisted research. All specifications reviewed and validated by Nihal N.

## Overview

This stage scans container images for known vulnerabilities (CVEs), generates a Software Bill of Materials (SBOM), validates licence compliance, verifies base image provenance, and signs the container image for supply chain security.

## Tool & Version

| Component | Specification |
|-----------|--------------|
| Container Scanner | Trivy 0.50+ |
| SBOM Generator | Syft 1.x (CycloneDX format) |
| Licence Scanner | Trivy licence scanning mode |
| Image Signing | Cosign 2.x (Sigstore) |
| Backup Scanner | Grype 0.74+ (secondary validation) |

## Configuration

### Trivy Scan Configuration

```yaml
# trivy.yaml
severity:
  - CRITICAL
  - HIGH
  - MEDIUM
ignore-unfixed: false
exit-code: 1
format: json
output: trivy-results.json
vuln-type:
  - os
  - library
security-checks:
  - vuln
  - secret
  - config
```

### SBOM Generation

```bash
# Generate SBOM in CycloneDX format
syft novapay-app:${GIT_SHA} -o cyclonedx-json > sbom-cyclonedx.json

# Also generate SPDX for regulatory cross-reference
syft novapay-app:${GIT_SHA} -o spdx-json > sbom-spdx.json
```

### Image Signing with Cosign

```bash
# Sign the container image
cosign sign --key cosign.key \
  --annotations "commit=${GIT_SHA}" \
  --annotations "pipeline=${PIPELINE_RUN_ID}" \
  --annotations "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  artifactory.novapay.internal/docker-local/novapay-app:${VERSION}

# Attach SBOM as attestation
cosign attest --key cosign.key \
  --predicate sbom-cyclonedx.json \
  --type cyclonedx \
  artifactory.novapay.internal/docker-local/novapay-app:${VERSION}
```

## Quality Gate

| Check | Threshold | Enforcement |
|-------|-----------|-------------|
| Critical CVEs | 0 (zero tolerance) | Hard block |
| High CVEs (CVSS ≥ 8.0) | 0 | Hard block |
| High CVEs (CVSS < 8.0) | ≤ 3 | Soft warning |
| Medium CVEs | Report only | Soft warning |
| SBOM generation | Must succeed | Hard block |
| Licence compliance | No GPL/AGPL/SSPL | Hard block |
| Base image provenance | Verified publisher | Hard block |
| Image signing | Must succeed | Hard block |
| Secret detection | 0 secrets found | Hard block |

### CVE Severity Gating Logic

```
if CRITICAL CVE found → BLOCK pipeline immediately
if HIGH CVE with CVSS ≥ 9.0 → BLOCK pipeline, 72h remediation window
if HIGH CVE with CVSS ≥ 8.0 → BLOCK pipeline, notify security team
if HIGH CVE with CVSS < 8.0 → WARNING, allow proceed with acknowledgement
if MEDIUM CVE → LOG, include in weekly vulnerability report
```

## Licence Compliance

### Blacklisted Licences (Banking Context)

| Licence | Risk | Action |
|---------|------|--------|
| GPL v2/v3 | Copyleft — may require source disclosure | Pipeline blocked |
| AGPL v3 | Network copyleft — severe risk for SaaS banking | Pipeline blocked |
| SSPL | Server-side restriction | Pipeline blocked |
| EUPL | Copyleft with compatibility concerns | Legal review triggered |

### Permitted Licences

MIT, Apache 2.0, BSD 2-Clause, BSD 3-Clause, ISC, MPL 2.0, Unlicense

## Failure Modes & Remediation

| Failure | Cause | Remediation |
|---------|-------|-------------|
| Critical CVE detected | Vulnerable dependency | Update dependency, patch, or apply workaround |
| GPL dependency found | Transitive dependency pulled in GPL lib | Replace with permissively-licensed alternative |
| SBOM generation failed | Unsupported image format | Verify Dockerfile follows standard conventions |
| Cosign signing failed | Key management issue | Check KMS configuration, rotate keys if needed |
| Base image not verified | Using unofficial base image | Switch to verified publisher images (Eclipse Temurin) |

## Exception Process

1. Security engineer files CVE exception with business justification
2. Compensating controls documented (WAF rule, network isolation, etc.)
3. CISO approval required within 24 hours
4. Exception auto-expires after 72 hours (Critical) or 30 days (High)
5. Exception tracked in vulnerability management system

## SLA Target

| Metric | Target |
|--------|--------|
| Container scan duration | < 5 minutes |
| SBOM generation | < 2 minutes |
| Image signing | < 1 minute |
| Total stage duration | < 10 minutes |

## RBI/PCI-DSS Mapping

- **RBI Section 5.1**: Vulnerability assessment — container scanning on every build
- **RBI Section 7.2**: Third-party risk management — licence compliance + SBOM
- **PCI-DSS Req 6.3**: Security vulnerabilities — CVE scanning with severity gating
