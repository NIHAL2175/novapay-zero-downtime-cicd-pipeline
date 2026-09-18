#!/usr/bin/env bash
# NovaPay — Code Coverage Threshold Checker
# Usage: ./check-coverage.sh --type line|branch [--min <threshold>]
# Reads JaCoCo XML report and extracts coverage percentages.
# Ref: Deliverable 1, Stage 2 — Build & Compilation

set -euo pipefail

REPORT_PATH="build/reports/jacoco/test/jacocoTestReport.xml"
COVERAGE_TYPE="line"
MIN_THRESHOLD=""

usage() {
    echo "Usage: $0 --type <line|branch> [--min <threshold>]"
    echo ""
    echo "Options:"
    echo "  --type       Coverage type: 'line' or 'branch'"
    echo "  --min        Minimum threshold (exits with error if below)"
    echo "  --min-line   Minimum line coverage (default: 80)"
    echo "  --min-branch Minimum branch coverage (default: 70)"
    echo "  --report     Path to JaCoCo XML report"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            COVERAGE_TYPE="$2"
            shift 2
            ;;
        --min)
            MIN_THRESHOLD="$2"
            shift 2
            ;;
        --min-line)
            if [ "$COVERAGE_TYPE" = "line" ]; then
                MIN_THRESHOLD="$2"
            fi
            shift 2
            ;;
        --min-branch)
            if [ "$COVERAGE_TYPE" = "branch" ]; then
                MIN_THRESHOLD="$2"
            fi
            shift 2
            ;;
        --report)
            REPORT_PATH="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

if [ ! -f "$REPORT_PATH" ]; then
    echo "ERROR: JaCoCo report not found at $REPORT_PATH"
    exit 1
fi

# Extract coverage from JaCoCo XML
if [ "$COVERAGE_TYPE" = "line" ]; then
    COUNTER_TYPE="LINE"
    DEFAULT_MIN=80
elif [ "$COVERAGE_TYPE" = "branch" ]; then
    COUNTER_TYPE="BRANCH"
    DEFAULT_MIN=70
else
    echo "ERROR: Unknown coverage type '$COVERAGE_TYPE'. Use 'line' or 'branch'."
    exit 1
fi

MIN_THRESHOLD="${MIN_THRESHOLD:-$DEFAULT_MIN}"

# Parse JaCoCo XML report — extract missed and covered counts
MISSED=$(grep -o "type=\"${COUNTER_TYPE}\" missed=\"[0-9]*\"" "$REPORT_PATH" | tail -1 | grep -o 'missed="[0-9]*"' | grep -o '[0-9]*')
COVERED=$(grep -o "type=\"${COUNTER_TYPE}\" missed=\"[0-9]*\" covered=\"[0-9]*\"" "$REPORT_PATH" | tail -1 | grep -o 'covered="[0-9]*"' | grep -o '[0-9]*')

if [ -z "$MISSED" ] || [ -z "$COVERED" ]; then
    echo "ERROR: Could not parse ${COUNTER_TYPE} coverage from report"
    exit 1
fi

TOTAL=$((MISSED + COVERED))
if [ "$TOTAL" -eq 0 ]; then
    COVERAGE="0"
else
    COVERAGE=$(echo "scale=2; ($COVERED * 100) / $TOTAL" | bc)
fi

echo "$COVERAGE"

# Check against threshold if in validation mode
if [ -n "$MIN_THRESHOLD" ]; then
    if (( $(echo "$COVERAGE < $MIN_THRESHOLD" | bc -l) )); then
        echo "FAIL: ${COVERAGE_TYPE} coverage ${COVERAGE}% is below minimum ${MIN_THRESHOLD}%" >&2
        exit 1
    fi
fi
