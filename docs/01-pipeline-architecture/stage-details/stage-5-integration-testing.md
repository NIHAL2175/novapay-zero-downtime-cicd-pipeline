# Stage 5: Integration & Contract Testing

> **AI Attribution Block**: Developed with AI-assisted research. All specifications reviewed and validated by Nihal N.

## Overview

This stage validates that NovaPay's microservices interact correctly by running consumer-driven contract tests, database integration tests, and API backward compatibility checks in ephemeral Kubernetes namespaces.

## Tool & Version

| Component | Specification |
|-----------|--------------|
| Contract Testing | Pact 5.x (JVM) |
| Integration Testing | Testcontainers 1.19+ |
| Ephemeral Namespaces | Kubernetes + Helm (auto-provisioned) |
| API Compatibility | OpenAPI Diff |
| Database Testing | Flyway 10.x + Testcontainers PostgreSQL |
| Performance Baseline | Gatling 3.x (lightweight baseline) |

## Configuration

### Ephemeral Namespace Provisioning

```yaml
# Each PR gets an isolated test environment
namespace: novapay-test-pr-${PR_NUMBER}
resources:
  postgresql: PostgreSQL 16 (Testcontainers)
  redis: Redis 7 (Testcontainers)
  rabbitmq: RabbitMQ 3.13 (Testcontainers)
  app: NovaPay microservices (current build)
lifecycle:
  creation: Automatic on pipeline trigger
  cleanup: Automatic after tests complete (TTL: 2 hours max)
```

### Consumer-Driven Contract Tests (Pact)

```java
// Example: Payment Service consumer contract
@PactTestFor(providerName = "account-service", port = "8081")
public class PaymentServiceContractTest {
    @Pact(consumer = "payment-service")
    public V4Pact accountBalancePact(PactDslWithProvider builder) {
        return builder
            .given("account 12345678 exists with balance 50000")
            .uponReceiving("a request for account balance")
            .path("/api/v1/accounts/12345678/balance")
            .method("GET")
            .willRespondWith()
            .status(200)
            .body(newJsonBody(body -> {
                body.stringType("accountId", "12345678");
                body.numberType("balance", 50000);
                body.stringType("currency", "INR");
            }).build())
            .toPact(V4Pact.class);
    }
}
```

### API Backward Compatibility Check

```bash
# Compare current OpenAPI spec against production baseline
openapi-diff \
  --fail-on-incompatible \
  baseline/openapi-v2.13.yaml \
  current/openapi-v2.14.yaml
```

## Quality Gate

| Check | Threshold | Enforcement |
|-------|-----------|-------------|
| Contract test pass rate | 100% | Hard block |
| Integration test pass rate | 100% | Hard block |
| API backward compatibility | No breaking changes | Hard block |
| Database migration tests | All migrations apply cleanly | Hard block |
| Ephemeral env provisioning | < 3 minutes | Soft warning |
| Performance baseline | p99 latency < 500ms under 1x load | Soft warning |

## Test Categories

### Contract Tests
- **Payment → Account Service**: Balance queries, debit/credit operations
- **Payment → Notification Service**: Transaction alerts, OTP delivery
- **API Gateway → All Services**: Authentication, routing, rate limiting
- **Compliance Reporter → Audit Service**: Audit log queries, report generation

### Database Integration Tests
- Schema migration applies without error (Flyway)
- Data integrity constraints validated
- Backward compatibility: V(N-1) queries work against V(N) schema
- Forward compatibility: V(N) queries work against V(N-1) schema (expand phase)
- Connection pool behaviour under load (pgBouncer)

### Performance Baseline
- Establish response time baseline (p50, p95, p99) for critical API paths
- Ensure no regression > 20% compared to previous build
- Run with 1x expected production load (scaled down)

## Failure Modes & Remediation

| Failure | Cause | Remediation |
|---------|-------|-------------|
| Contract test failure | Provider changed API without updating contract | Coordinate with provider team, update contract |
| Integration test failure | Service dependency issue | Check logs, fix service interaction |
| API breaking change | Removed/renamed endpoint or field | Use deprecation pattern, maintain backward compat |
| Ephemeral env timeout | Resource quota exceeded | Clean up stale namespaces, increase quota |
| Database migration failure | Invalid SQL or constraint violation | Fix migration script, test locally first |

## Retry/Skip Logic

- **Retry**: Flaky test detection — if a test fails, retry up to 2 times before marking as failed
- **Quarantine**: Tests failing > 3 times in 7 days are quarantined with auto-ticket
- **Skip**: Performance baseline is advisory (soft warning) and does not block the pipeline

## SLA Target

| Metric | Target |
|--------|--------|
| Ephemeral env provisioning | < 3 minutes |
| Contract tests | < 5 minutes |
| Integration tests | < 10 minutes |
| Total stage duration | < 18 minutes |

## RBI/PCI-DSS Mapping

- **RBI Section 4.2**: Testing as part of change management process
- **PCI-DSS Req 6.2**: Bespoke software security — integration testing validates secure interactions
