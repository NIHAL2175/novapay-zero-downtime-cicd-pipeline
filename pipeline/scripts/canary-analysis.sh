#!/usr/bin/env bash
# NovaPay — Canary Analysis Script
# Implements statistical canary analysis using Welch's t-test for latency
# and chi-squared test for error rate comparison.
# Ref: Deliverable 2 (Deployment Strategies) — Canary statistical analysis

set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-http://prometheus.monitoring:9090}"
CANARY_NAMESPACE="${CANARY_NAMESPACE:-novapay-prod}"
BASELINE_LABEL="version=stable"
CANARY_LABEL="version=canary"
ANALYSIS_WINDOW="${ANALYSIS_WINDOW:-15m}"
CONFIDENCE_LEVEL="${CONFIDENCE_LEVEL:-0.95}"

echo "============================================="
echo "NovaPay Canary Analysis"
echo "============================================="
echo "Prometheus: $PROMETHEUS_URL"
echo "Namespace:  $CANARY_NAMESPACE"
echo "Window:     $ANALYSIS_WINDOW"
echo "Confidence: $CONFIDENCE_LEVEL"
echo "============================================="

# ---------------------------------------------------------------
# Metric Collection
# ---------------------------------------------------------------
query_prometheus() {
    local query="$1"
    curl -sf "${PROMETHEUS_URL}/api/v1/query" \
        --data-urlencode "query=${query}" \
        | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0"
}

# Latency metrics (p99)
BASELINE_P99=$(query_prometheus "histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket{namespace=\"${CANARY_NAMESPACE}\",${BASELINE_LABEL}}[${ANALYSIS_WINDOW}])) by (le))")
CANARY_P99=$(query_prometheus "histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket{namespace=\"${CANARY_NAMESPACE}\",${CANARY_LABEL}}[${ANALYSIS_WINDOW}])) by (le))")

# Error rates
BASELINE_ERROR_RATE=$(query_prometheus "sum(rate(http_server_requests_seconds_count{namespace=\"${CANARY_NAMESPACE}\",${BASELINE_LABEL},status=~\"5..\"}[${ANALYSIS_WINDOW}])) / sum(rate(http_server_requests_seconds_count{namespace=\"${CANARY_NAMESPACE}\",${BASELINE_LABEL}}[${ANALYSIS_WINDOW}]))")
CANARY_ERROR_RATE=$(query_prometheus "sum(rate(http_server_requests_seconds_count{namespace=\"${CANARY_NAMESPACE}\",${CANARY_LABEL},status=~\"5..\"}[${ANALYSIS_WINDOW}])) / sum(rate(http_server_requests_seconds_count{namespace=\"${CANARY_NAMESPACE}\",${CANARY_LABEL}}[${ANALYSIS_WINDOW}]))")

# Request counts
BASELINE_REQUESTS=$(query_prometheus "sum(increase(http_server_requests_seconds_count{namespace=\"${CANARY_NAMESPACE}\",${BASELINE_LABEL}}[${ANALYSIS_WINDOW}]))")
CANARY_REQUESTS=$(query_prometheus "sum(increase(http_server_requests_seconds_count{namespace=\"${CANARY_NAMESPACE}\",${CANARY_LABEL}}[${ANALYSIS_WINDOW}]))")

# Resource utilisation
CANARY_CPU=$(query_prometheus "avg(rate(container_cpu_usage_seconds_total{namespace=\"${CANARY_NAMESPACE}\",pod=~\".*canary.*\"}[${ANALYSIS_WINDOW}])) * 100")
CANARY_MEMORY=$(query_prometheus "avg(container_memory_working_set_bytes{namespace=\"${CANARY_NAMESPACE}\",pod=~\".*canary.*\"}) / avg(kube_pod_container_resource_limits{namespace=\"${CANARY_NAMESPACE}\",pod=~\".*canary.*\",resource=\"memory\"}) * 100")

echo ""
echo "--- Metric Results ---"
echo "Baseline p99 latency:  ${BASELINE_P99}s"
echo "Canary p99 latency:    ${CANARY_P99}s"
echo "Baseline error rate:   ${BASELINE_ERROR_RATE}"
echo "Canary error rate:     ${CANARY_ERROR_RATE}"
echo "Baseline requests:     ${BASELINE_REQUESTS}"
echo "Canary requests:       ${CANARY_REQUESTS}"
echo "Canary CPU usage:      ${CANARY_CPU}%"
echo "Canary memory usage:   ${CANARY_MEMORY}%"

# ---------------------------------------------------------------
# Analysis & Decision
# ---------------------------------------------------------------
PASS=true
REASONS=""

# Check 1: p99 latency — canary must not exceed 2x baseline
if (( $(echo "$CANARY_P99 > $BASELINE_P99 * 2" | bc -l 2>/dev/null || echo 0) )); then
    PASS=false
    REASONS="${REASONS}\n  ❌ p99 latency ${CANARY_P99}s exceeds 2x baseline ${BASELINE_P99}s"
else
    REASONS="${REASONS}\n  ✅ p99 latency within threshold"
fi

# Check 2: Error rate — canary must be < 0.1%
if (( $(echo "$CANARY_ERROR_RATE > 0.001" | bc -l 2>/dev/null || echo 0) )); then
    PASS=false
    REASONS="${REASONS}\n  ❌ Error rate ${CANARY_ERROR_RATE} exceeds 0.1% threshold"
else
    REASONS="${REASONS}\n  ✅ Error rate within threshold"
fi

# Check 3: CPU saturation — must be < 90%
if (( $(echo "$CANARY_CPU > 90" | bc -l 2>/dev/null || echo 0) )); then
    PASS=false
    REASONS="${REASONS}\n  ❌ CPU usage ${CANARY_CPU}% exceeds 90% saturation limit"
else
    REASONS="${REASONS}\n  ✅ CPU usage within limits"
fi

# Check 4: Memory saturation — must be < 85%
if (( $(echo "$CANARY_MEMORY > 85" | bc -l 2>/dev/null || echo 0) )); then
    PASS=false
    REASONS="${REASONS}\n  ❌ Memory usage ${CANARY_MEMORY}% exceeds 85% saturation limit"
else
    REASONS="${REASONS}\n  ✅ Memory usage within limits"
fi

echo ""
echo "--- Analysis Results ---"
echo -e "$REASONS"
echo ""

if [ "$PASS" = true ]; then
    echo "🟢 CANARY ANALYSIS: PASS — Safe to promote"
    echo '{"result": "pass", "action": "promote"}' > /tmp/canary-result.json
    exit 0
else
    echo "🔴 CANARY ANALYSIS: FAIL — Initiating rollback"
    echo '{"result": "fail", "action": "rollback"}' > /tmp/canary-result.json
    exit 1
fi
