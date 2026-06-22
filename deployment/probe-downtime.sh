#!/usr/bin/env bash
# Measure real deploy downtime as seen from outside.
#
# Run it on your laptop in one terminal, trigger a deploy (push to main or
# `workflow_dispatch`) in another, then Ctrl-C to print the summary. The
# "longest outage" number is the one to watch: before this change it was ~5 min,
# the target after it is 0.
#
# api.aivus.co/healthz measures the Traefik-gated path (the one this change makes
# truly zero-downtime). The frontend->django internal SSR path (http://django:5000)
# bypasses Traefik and keeps a few-second blip during rollout — see DEPLOYMENT.md.
#
# Usage:
#   ./probe-downtime.sh https://api.aivus.co/healthz [interval_seconds]
#   ./probe-downtime.sh https://api.aivus.co/healthz 0.2

set -u

URL="${1:?usage: probe-downtime.sh URL [interval_seconds]}"
INTERVAL="${2:-0.2}"

total=0
ok=0
fail=0
cur_streak=0
max_streak=0

summary() {
  echo ""
  echo "=========================================="
  echo "Probe summary for $URL"
  echo "  requests:        $total"
  echo "  ok (2xx/3xx):    $ok"
  echo "  failed:          $fail"
  if [ "$fail" -gt 0 ]; then
    approx=$(awk "BEGIN { printf \"%.1f\", $fail * $INTERVAL }")
    longest=$(awk "BEGIN { printf \"%.1f\", $max_streak * $INTERVAL }")
    echo "  approx downtime: ~${approx}s total"
    echo "  longest outage:  ~${longest}s (${max_streak} consecutive failures)"
  else
    echo "  downtime:        0s (zero-downtime confirmed)"
  fi
  echo "=========================================="
  exit 0
}
trap summary INT TERM

echo "Probing $URL every ${INTERVAL}s. Trigger a deploy, then Ctrl-C for the summary."
while true; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$URL" || echo "000")
  total=$((total + 1))
  if [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
    ok=$((ok + 1))
    cur_streak=0
    printf "\r[%s] ok=%d fail=%d last=%s   " "$(date +%H:%M:%S)" "$ok" "$fail" "$code"
  else
    fail=$((fail + 1))
    cur_streak=$((cur_streak + 1))
    if [ "$cur_streak" -gt "$max_streak" ]; then
      max_streak=$cur_streak
    fi
    echo ""
    echo "[$(date +%H:%M:%S)] DOWN code=$code (streak=$cur_streak)"
  fi
  sleep "$INTERVAL"
done
