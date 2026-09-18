#!/usr/bin/env bash
# NovaPay — SBOM Generation & Archival Script
# Generates CycloneDX SBOM, signs it, and archives to compliance store.
# Ref: Deliverable 1 (Stage 4), Deliverable 3 (Compliance Gates)

set -euo pipefail

IMAGE_REF="${1:?Usage: sbom-archive.sh <image-ref> [output-dir]}"
OUTPUT_DIR="${2:-./sbom-output}"
ARCHIVE_BUCKET="${SBOM_ARCHIVE_BUCKET:-s3://novapay-compliance-evidence/sbom}"

mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
IMAGE_TAG=$(echo "$IMAGE_REF" | awk -F: '{print $2}')
SBOM_FILE="${OUTPUT_DIR}/sbom-${IMAGE_TAG}-${TIMESTAMP}.json"

echo "============================================="
echo "NovaPay SBOM Generation"
echo "============================================="
echo "Image:     $IMAGE_REF"
echo "Output:    $SBOM_FILE"
echo "Timestamp: $TIMESTAMP"
echo "============================================="

# Step 1: Generate SBOM using Syft
echo "[1/4] Generating SBOM (CycloneDX format)..."
syft "$IMAGE_REF" -o cyclonedx-json > "$SBOM_FILE"

COMPONENT_COUNT=$(jq '.components | length' "$SBOM_FILE" 2>/dev/null || echo "unknown")
echo "  Components found: $COMPONENT_COUNT"

# Step 2: Validate SBOM
echo "[2/4] Validating SBOM structure..."
if jq -e '.bomFormat == "CycloneDX"' "$SBOM_FILE" > /dev/null 2>&1; then
    echo "  ✅ Valid CycloneDX SBOM"
else
    echo "  ❌ Invalid SBOM format"
    exit 1
fi

# Step 3: Sign SBOM attestation with Cosign
echo "[3/4] Attaching SBOM attestation to image..."
if command -v cosign &> /dev/null && [ -n "${COSIGN_PRIVATE_KEY:-}" ]; then
    cosign attest --key env://COSIGN_PRIVATE_KEY \
        --predicate "$SBOM_FILE" \
        --type cyclonedx \
        "$IMAGE_REF"
    echo "  ✅ SBOM attestation attached"
else
    echo "  ⚠️  Cosign not available — skipping attestation"
fi

# Step 4: Archive to compliance store
echo "[4/4] Archiving SBOM to compliance store..."
if command -v aws &> /dev/null; then
    aws s3 cp "$SBOM_FILE" \
        "${ARCHIVE_BUCKET}/${IMAGE_TAG}/${TIMESTAMP}/sbom.json" \
        --sse aws:kms 2>/dev/null || echo "  ⚠️  S3 upload skipped (no credentials)"
else
    echo "  ⚠️  AWS CLI not available — SBOM saved locally only"
fi

echo ""
echo "✅ SBOM generation complete"
echo "  File: $SBOM_FILE"
echo "  Components: $COMPONENT_COUNT"
