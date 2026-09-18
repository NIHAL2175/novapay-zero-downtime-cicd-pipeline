# Stage 2: Build & Compilation

> **AI Attribution Block**: Developed with AI-assisted research. All specifications reviewed and validated by Nihal N.

## Overview

The Build & Compilation stage transforms source code into deployable container images with verified test coverage. It enforces reproducible builds through dependency lock files and multi-stage Docker builds with layer caching.

## Tool & Version

| Component | Specification |
|-----------|--------------|
| Build Tool | Gradle 8.x with Kotlin DSL |
| Language | Java 21 (Eclipse Temurin) |
| Framework | Spring Boot 3.x |
| Container | Docker (multi-stage build) |
| Registry | JFrog Artifactory |
| Coverage | JaCoCo 0.8.x |

## Configuration

### Multi-Stage Dockerfile

```dockerfile
# Stage 1: Build
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY gradle/ gradle/
COPY gradlew build.gradle.kts settings.gradle.kts ./
RUN ./gradlew dependencies --no-daemon
COPY src/ src/
RUN ./gradlew build test jacocoTestReport --no-daemon -x integrationTest

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine AS runtime
RUN addgroup -S novapay && adduser -S novapay -G novapay
WORKDIR /app
COPY --from=builder /app/build/libs/novapay-*.jar app.jar
USER novapay
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:+UseG1GC", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
```

### Build Matrix

```yaml
strategy:
  matrix:
    java-version: [21]
    os: [ubuntu-latest]
  fail-fast: true
```

### Dependency Lock File Enforcement

```yaml
- name: Verify dependency lock
  run: |
    ./gradlew dependencies --write-locks
    if [ -n "$(git diff --name-only)" ]; then
      echo "ERROR: Dependency lock file out of sync. Run './gradlew dependencies --write-locks' locally."
      exit 1
    fi
```

## Quality Gate

| Check | Threshold | Enforcement |
|-------|-----------|-------------|
| Unit test pass rate | 100% (0 failures tolerated) | Hard block |
| Line coverage | ≥ 80% | Hard block |
| Branch coverage | ≥ 70% | Hard block |
| Build duration | < 12 minutes | Soft warning |
| Dependency lock sync | Lock file matches | Hard block |

## Artefact Output

```
Output: novapay-app:2.14.3+sha.a1b2c3d
Tags: [SemVer, GitSHA, build-timestamp]
Registry: artifactory.novapay.internal/docker-local/novapay-app
SBOM: Attached as build attestation
```

## Failure Modes & Remediation

| Failure | Cause | Remediation |
|---------|-------|-------------|
| Compilation error | Syntax/type errors | Fix code, re-push |
| Test failure | Logic error or regression | Review failing test, fix code |
| Coverage below threshold | Insufficient test coverage | Write additional unit tests |
| Docker build failure | Dependency resolution issue | Check Dockerfile, verify base image |
| Artifactory push failure | Network/auth issue | Retry (3 attempts), alert if persistent |

## Retry/Skip Logic

- **Retry**: Artifactory push retries 3 times with 10s backoff
- **Cache**: Gradle dependency cache + Docker layer cache to reduce build time by ~60%
- **Skip**: Integration tests skipped in this stage (run in Stage 5)

## SLA Target

| Metric | Target |
|--------|--------|
| Build + unit test duration | < 12 minutes |
| Docker image build | < 3 minutes (cached) |
| Artifactory push | < 30 seconds |

## RBI/PCI-DSS Mapping

- **RBI Section 4.2**: Automated build process ensures consistent, repeatable deployments
- **PCI-DSS Req 6.2**: Bespoke software developed with secure coding practices and tested
