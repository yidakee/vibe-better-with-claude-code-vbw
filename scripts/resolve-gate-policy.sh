#!/usr/bin/env bash
set -u

# resolve-gate-policy.sh <effort> <risk> <autonomy>
# Resolves the validation gate policy from effort level, plan risk, and autonomy.
# Output: JSON object with qa_tier, approval_required, communication_level, two_phase.
#
# Gate matrix:
#   turbo: always skip approval, skip QA, no communication
#   fast+low/medium: light QA, no approval, blockers only
#   fast+high: light QA, approval required, blockers only
#   balanced+low: standard QA, no approval, blockers+findings
#   balanced+medium: standard QA, cautious=approval, blockers+findings
#   balanced+high: standard QA, approval required, blockers+findings
#   thorough+any: deep QA, approval (cautious/standard), full communication
#
# High risk at non-turbo effort always forces approval regardless of autonomy
# (except confident/pure-vibe which only get approval at thorough)
#
# Fail-open: defaults to balanced/medium/standard on any error.

if [ $# -lt 3 ]; then
  echo '{"qa_tier":"standard","approval_required":false,"communication_level":"blockers","two_phase":false}'
  exit 0
fi

EFFORT="$1"
RISK="$2"
AUTONOMY="$3"

# Resolve QA tier
case "$EFFORT" in
  turbo)   QA_TIER="skip" ;;
  fast)    QA_TIER="quick" ;;
  balanced) QA_TIER="standard" ;;
  thorough) QA_TIER="deep" ;;
  *)       QA_TIER="standard" ;;
esac

# Resolve communication level
case "$EFFORT" in
  turbo)    COMM="none" ;;
  fast)     COMM="blockers" ;;
  balanced) COMM="blockers_findings" ;;
  thorough) COMM="full" ;;
  *)        COMM="blockers" ;;
esac

# Resolve approval requirement
APPROVAL=false
TWO_PHASE=false

case "$EFFORT" in
  turbo)
    # Turbo never requires approval
    APPROVAL=false
    ;;
  fast)
    # Fast: only high risk forces approval (except confident/pure-vibe)
    if [ "$RISK" = "high" ]; then
      case "$AUTONOMY" in
        cautious|standard) APPROVAL=true; TWO_PHASE=true ;;
      esac
    fi
    ;;
  balanced)
    if [ "$RISK" = "high" ]; then
      # High risk at balanced: approval for cautious/standard
      case "$AUTONOMY" in
        cautious|standard) APPROVAL=true; TWO_PHASE=true ;;
      esac
    elif [ "$RISK" = "medium" ]; then
      # Medium risk: only cautious gets approval
      case "$AUTONOMY" in
        cautious) APPROVAL=true ;;
      esac
    fi
    ;;
  thorough)
    # Thorough: approval for cautious and standard
    case "$AUTONOMY" in
      cautious|standard) APPROVAL=true; TWO_PHASE=true ;;
    esac
    ;;
esac

# Output JSON
if command -v jq &>/dev/null; then
  jq -n \
    --arg qa_tier "$QA_TIER" \
    --argjson approval "$APPROVAL" \
    --arg communication_level "$COMM" \
    --argjson two_phase "$TWO_PHASE" \
    '{qa_tier: $qa_tier, approval_required: $approval, communication_level: $communication_level, two_phase: $two_phase}'
else
  echo "{\"qa_tier\":\"${QA_TIER}\",\"approval_required\":${APPROVAL},\"communication_level\":\"${COMM}\",\"two_phase\":${TWO_PHASE}}"
fi
