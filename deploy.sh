#!/usr/bin/env bash
# vrthurman.github.io publishes via GITHUB PAGES — pushing to main IS the
# deploy. Cloudflare only hosts the samsara-design APIs; deploying there does
# NOT update this site. This script pushes AND waits until Pages serves it.
#
#   ./deploy.sh "commit message"
set -euo pipefail
MSG="${1:-site update}"

command git add -A
command git diff --cached --quiet || command git commit -m "$MSG"
HEAD=$(command git rev-parse HEAD)

PREV=$(gh api user --jq .login 2>/dev/null || echo "")
gh auth switch -u vrthurman >/dev/null
command git push origin main
echo "pushed $HEAD — waiting for GitHub Pages build…"

STATUS=""
for i in $(seq 1 40); do
  sleep 15
  STATUS=$(gh api repos/vrthurman/vrthurman.github.io/pages/builds/latest --jq '.status+" "+.commit' 2>/dev/null || echo unknown)
  echo "  [$i] $STATUS"
  case "$STATUS" in
    "built $HEAD") echo "✓ built — verifying live…"; break;;
    errored*) echo "✗ Pages build errored — see repo settings/actions"; break;;
  esac
done
[ -n "$PREV" ] && [ "$PREV" != "vrthurman" ] && gh auth switch -u "$PREV" >/dev/null || true

if [ "$STATUS" = "built $HEAD" ]; then
  sleep 10
  if curl -s "https://vrthurman.github.io/?cb=$(date +%s)" | grep -q "roster.html"; then
    echo "✓ LIVE at https://vrthurman.github.io"
  else
    echo "⚠ built but CDN still serving old HTML — give it a minute + hard refresh"
  fi
fi
