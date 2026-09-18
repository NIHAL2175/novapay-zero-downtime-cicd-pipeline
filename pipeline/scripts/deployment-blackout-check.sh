#!/usr/bin/env bash
# NovaPay — Deployment Blackout Calendar Check
# Validates whether the current time is safe for deployment.
# Blocks during: salary days, peak hours, festivals, RBI settlement windows.
# Ref: Deliverable 2 (Deployment Strategies), Case Study 4 (SBI YONO)

set -euo pipefail

FORCE="${FORCE:-false}"
TIMEZONE="${TIMEZONE:-Asia/Kolkata}"
EXIT_CODE=0

# Get current date/time in IST
CURRENT_HOUR=$(TZ=$TIMEZONE date +%H)
CURRENT_DAY=$(TZ=$TIMEZONE date +%d)
CURRENT_MONTH=$(TZ=$TIMEZONE date +%m)
CURRENT_DOW=$(TZ=$TIMEZONE date +%u)  # 1=Monday, 7=Sunday
CURRENT_DATE=$(TZ=$TIMEZONE date +%Y-%m-%d)

echo "============================================="
echo "NovaPay Deployment Blackout Check"
echo "============================================="
echo "Current time (IST): $(TZ=$TIMEZONE date '+%Y-%m-%d %H:%M:%S %Z')"
echo "============================================="

BLOCKED=false
WARNINGS=""
BLOCKS=""

# ---------------------------------------------------------------
# Check 1: Salary Days (1st, 7th, 15th of month)
# ---------------------------------------------------------------
if [[ "$CURRENT_DAY" == "01" || "$CURRENT_DAY" == "07" || "$CURRENT_DAY" == "15" ]]; then
    BLOCKED=true
    BLOCKS="${BLOCKS}\n  🚫 BLOCKED: Salary day (${CURRENT_DAY}th) — high UPI/NEFT traffic expected"
fi

# ---------------------------------------------------------------
# Check 2: Month-end Processing (28th–31st)
# ---------------------------------------------------------------
if [[ "$CURRENT_DAY" -ge 28 ]]; then
    BLOCKED=true
    BLOCKS="${BLOCKS}\n  🚫 BLOCKED: Month-end processing window (${CURRENT_DAY}th)"
fi

# ---------------------------------------------------------------
# Check 3: Peak Hours (10AM-12PM and 5PM-8PM IST)
# ---------------------------------------------------------------
if [[ "$CURRENT_HOUR" -ge 10 && "$CURRENT_HOUR" -lt 12 ]] || \
   [[ "$CURRENT_HOUR" -ge 17 && "$CURRENT_HOUR" -lt 20 ]]; then
    BLOCKED=true
    BLOCKS="${BLOCKS}\n  🚫 BLOCKED: Peak traffic hours (${CURRENT_HOUR}:00 IST)"
fi

# ---------------------------------------------------------------
# Check 4: Major Festivals (approximate dates — update annually)
# ---------------------------------------------------------------
FESTIVAL_DATES=(
    "2026-10-20"  # Diwali
    "2026-10-21"  # Diwali (Day 2)
    "2026-03-17"  # Holi
    "2026-03-31"  # Eid al-Fitr (approximate)
    "2026-12-25"  # Christmas
    "2026-01-26"  # Republic Day
    "2026-08-15"  # Independence Day
    "2026-11-01"  # Bhai Dooj
)

for FESTIVAL in "${FESTIVAL_DATES[@]}"; do
    if [[ "$CURRENT_DATE" == "$FESTIVAL" ]]; then
        BLOCKED=true
        BLOCKS="${BLOCKS}\n  🚫 BLOCKED: Festival/holiday — ${FESTIVAL}"
    fi
done

# ---------------------------------------------------------------
# Check 5: RBI Settlement Windows (RTGS/NEFT processing)
# ---------------------------------------------------------------
if [[ "$CURRENT_HOUR" -ge 8 && "$CURRENT_HOUR" -lt 9 ]] || \
   [[ "$CURRENT_HOUR" -ge 14 && "$CURRENT_HOUR" -lt 15 ]]; then
    WARNINGS="${WARNINGS}\n  ⚠️  WARNING: RBI settlement window — deploy with caution"
fi

# ---------------------------------------------------------------
# Check 6: Friday evening (risk of weekend incidents)
# ---------------------------------------------------------------
if [[ "$CURRENT_DOW" == "5" && "$CURRENT_HOUR" -ge 16 ]]; then
    WARNINGS="${WARNINGS}\n  ⚠️  WARNING: Friday evening deployment — weekend on-call risk"
fi

# ---------------------------------------------------------------
# Results
# ---------------------------------------------------------------
echo ""
if [ -n "$BLOCKS" ]; then
    echo "--- DEPLOYMENT BLOCKS ---"
    echo -e "$BLOCKS"
fi

if [ -n "$WARNINGS" ]; then
    echo ""
    echo "--- WARNINGS ---"
    echo -e "$WARNINGS"
fi

echo ""
if [ "$BLOCKED" = true ]; then
    if [ "$FORCE" = "true" ]; then
        echo "⚠️  FORCE FLAG SET — Proceeding despite blackout window"
        echo "    Approval required: Release Manager + SRE Lead"
        exit 0
    else
        echo "🔴 DEPLOYMENT BLOCKED — Current time is within a blackout window"
        echo "    Use FORCE=true to override (requires dual approval)"
        exit 1
    fi
else
    echo "🟢 DEPLOYMENT ALLOWED — No blackout restrictions active"
    exit 0
fi
