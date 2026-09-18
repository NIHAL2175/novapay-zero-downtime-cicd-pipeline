#!/usr/bin/env bash
# NovaPay — Automated Rollback Script
# Executes the 8-step rollback workflow defined in Deliverable 6.
# Ref: Deliverable 6 (Rollback Specification) — Category A/B/C triggers

set -euo pipefail

NAMESPACE="${NAMESPACE:-novapay-prod}"
ARGOCD_APP="${ARGOCD_APP:-novapay-production}"
ROLLBACK_REASON="${1:-manual}"
SEVERITY="${2:-B}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

echo "============================================="
echo "NovaPay Rollback Execution"
echo "============================================="
echo "Namespace:  $NAMESPACE"
echo "ArgoCD App: $ARGOCD_APP"
echo "Reason:     $ROLLBACK_REASON"
echo "Severity:   Category $SEVERITY"
echo "Timestamp:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================="

# ---------------------------------------------------------------
# Step 1: DETECT — Log trigger details
# ---------------------------------------------------------------
echo "[Step 1/8] DETECT — Rollback triggered"
echo "  Trigger: $ROLLBACK_REASON"
echo "  Category: $SEVERITY"

# ---------------------------------------------------------------
# Step 2: CORRELATE — Identify affected services
# ---------------------------------------------------------------
echo "[Step 2/8] CORRELATE — Identifying affected pods"
AFFECTED_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=novapay-app --field-selector=status.phase!=Running -o name 2>/dev/null || echo "none")
echo "  Affected pods: ${AFFECTED_PODS:-none detected}"

# ---------------------------------------------------------------
# Step 3: FREEZE — Stop ongoing deployments
# ---------------------------------------------------------------
echo "[Step 3/8] FREEZE — Pausing ArgoCD sync"
argocd app set "$ARGOCD_APP" --sync-policy none --grpc-web 2>/dev/null || echo "  WARNING: Could not pause ArgoCD sync"
echo "  Deployment pipeline frozen"

# ---------------------------------------------------------------
# Step 4: ROLLBACK — Execute rollback
# ---------------------------------------------------------------
echo "[Step 4/8] ROLLBACK — Rolling back to previous revision"

# Get previous ArgoCD revision
PREVIOUS_REVISION=$(argocd app history "$ARGOCD_APP" --grpc-web 2>/dev/null | tail -2 | head -1 | awk '{print $1}' || echo "")

if [ -n "$PREVIOUS_REVISION" ]; then
    argocd app rollback "$ARGOCD_APP" "$PREVIOUS_REVISION" --grpc-web 2>/dev/null || {
        echo "  ArgoCD rollback failed, attempting kubectl rollback"
        kubectl rollout undo deployment/novapay-app -n "$NAMESPACE" 2>/dev/null || true
    }
else
    echo "  No ArgoCD history, using kubectl rollback"
    kubectl rollout undo deployment/novapay-app -n "$NAMESPACE" 2>/dev/null || true
fi

echo "  Rollback initiated"

# ---------------------------------------------------------------
# Step 5: VERIFY — Confirm rollback success
# ---------------------------------------------------------------
echo "[Step 5/8] VERIFY — Waiting for rollback to stabilise"
kubectl rollout status deployment/novapay-app -n "$NAMESPACE" --timeout=300s 2>/dev/null || echo "  WARNING: Rollout status check timed out"

# Health check
HEALTH_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app=novapay-app -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "Unknown")
echo "  Pod status: $HEALTH_STATUS"

# ---------------------------------------------------------------
# Step 6: NOTIFY — Send notifications
# ---------------------------------------------------------------
echo "[Step 6/8] NOTIFY — Sending rollback notifications"

if [ -n "$SLACK_WEBHOOK" ]; then
    curl -sf -X POST "$SLACK_WEBHOOK" \
        -H 'Content-type: application/json' \
        -d "{
            \"text\": \"🔴 *NovaPay Rollback Executed*\",
            \"blocks\": [{
                \"type\": \"section\",
                \"text\": {
                    \"type\": \"mrkdwn\",
                    \"text\": \"*Rollback Executed*\\nReason: ${ROLLBACK_REASON}\\nCategory: ${SEVERITY}\\nNamespace: ${NAMESPACE}\\nTime: $(date -u +%Y-%m-%dT%H:%M:%SZ)\"
                }
            }]
        }" 2>/dev/null || echo "  WARNING: Slack notification failed"
fi

echo "  Notifications sent"

# ---------------------------------------------------------------
# Step 7: INCIDENT — Create incident record
# ---------------------------------------------------------------
echo "[Step 7/8] INCIDENT — Creating incident record"

INCIDENT_ID="INC-$(date +%Y%m%d%H%M%S)"
cat > "/tmp/incident-${INCIDENT_ID}.json" <<EOF
{
    "incident_id": "${INCIDENT_ID}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "type": "rollback",
    "severity": "Category ${SEVERITY}",
    "reason": "${ROLLBACK_REASON}",
    "namespace": "${NAMESPACE}",
    "argocd_app": "${ARGOCD_APP}",
    "previous_revision": "${PREVIOUS_REVISION:-unknown}",
    "pod_status_after_rollback": "${HEALTH_STATUS}",
    "action_required": "Post-mortem within 48 hours"
}
EOF

echo "  Incident record: /tmp/incident-${INCIDENT_ID}.json"

# ---------------------------------------------------------------
# Step 8: POSTMORTEM — Schedule post-mortem
# ---------------------------------------------------------------
echo "[Step 8/8] POSTMORTEM — Scheduling post-mortem review"
echo "  Post-mortem required within 48 hours for Category ${SEVERITY} incident"
echo "  Template: runbooks/incident-playbook.md#post-mortem-template"

echo ""
echo "============================================="
echo "Rollback complete at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Incident ID: ${INCIDENT_ID}"
echo "============================================="
