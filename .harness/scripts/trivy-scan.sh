#!/bin/sh
# Trivy misconfiguration scan of one pipeline target. Run from the repository root, in the
# pinned Trivy image (POSIX sh; needs no extra tools). It uses no credentials.
#   trivy-scan.sh scan <out-dir>   write trivy.json and trivy.sarif, print the findings
#   trivy-scan.sh gate <out-dir>   exit 1 if there are findings at the configured severities
# Env, from manifest.yaml through read-manifest.sh:
#   scan: TARGET, SCAN_IGNORE_FILE (default .trivyignore)
#   gate: SCAN_SEVERITY (default HIGH,CRITICAL), SCAN_IGNORE_FAILURE (default false)
#
# Scanned: the target's .tf files, the modules they use, and local Helm charts that the target's
# env files use (rendered with the chart's own default values).
# Limit: Trivy has few or no checks for providers such as libvirt, Talos, Pi-hole or PostgreSQL,
# and in testing it missed a privileged Kubernetes pod written in Terraform. A clean Terraform
# result is weak evidence.
# Accepted findings go in the ignore file (one ID per line, with a comment saying why).
set -eu

MODE="${1:?usage: trivy-scan.sh scan|gate <out-dir>}"
OUT="${2:?usage: trivy-scan.sh scan|gate <out-dir>}"
fail() { echo "ERROR: $*" >&2; exit 1; }
REPO=$PWD
# Offline and repeatable: only the checks built into the pinned image.
OFFLINE="--skip-check-update --skip-version-check --disable-telemetry"

case "$MODE" in
scan)
  case "${TARGET:?}" in
    infra|kube-addons/prod|kube-addons/nonprod|databases/nonprod) ;;
    *) fail "unknown TARGET '$TARGET'" ;;
  esac

  SRC=$(mktemp -d)
  trap 'rm -rf "$SRC"' EXIT
  copy() { mkdir -p "$SRC/$(dirname "$1")"; cp "$1" "$SRC/$1"; }

  for f in $(find "$TARGET" -name '*.tf' ! -path '*/.terraform/*'); do copy "$f"; done
  [ -n "$(find "$SRC" -name '*.tf')" ] || fail "no .tf files found in $TARGET"

  # Modules named by uncommented "source" lines.
  MODULES=$(find "$TARGET" -name '*.tf' ! -path '*/.terraform/*' -exec cat {} + |
    sed -n 's#^[[:space:]]*source[[:space:]]*=[[:space:]]*"[./]*/modules/\([A-Za-z0-9_-]*\)".*#\1#p' | sort -u)
  for m in $MODULES; do
    [ -d "modules/$m" ] || fail "module modules/$m not found"
    for f in $(find "modules/$m" -name '*.tf'); do copy "$f"; done
  done

  # Local charts named by uncommented "chart:" lines in the target's env files.
  CHARTS=""
  if [ -d "$TARGET/envs" ]; then
    CHARTS=$(find "$TARGET/envs" -name '*.yaml' -exec cat {} + |
      sed -n 's#^[[:space:]]*chart:[[:space:]]*["'"'"']\{0,1\}\./charts/\([A-Za-z0-9_-]*\).*#\1#p' | sort -u)
  fi
  for c in $CHARTS; do
    [ -d "kube-addons/charts/$c" ] || fail "chart kube-addons/charts/$c not found"
    mkdir -p "$SRC/kube-addons/charts"
    cp -R "kube-addons/charts/$c" "$SRC/kube-addons/charts/$c"
  done

  echo "Trivy scan of $TARGET | modules: $(echo ${MODULES:-none}) | local charts: $(echo ${CHARTS:-none})"

  set --
  IGNORE="$REPO/${SCAN_IGNORE_FILE:-.trivyignore}"
  if [ -f "$IGNORE" ]; then
    echo "Using ignore file ${SCAN_IGNORE_FILE:-.trivyignore}"
    set -- --ignorefile "$IGNORE"
  fi
  mkdir -p "$OUT"
  rm -f "$OUT/trivy.json" "$OUT/trivy.sarif"
  (cd "$SRC" && trivy config $OFFLINE "$@" --exit-code 0 --format json --output "$OUT/trivy.json" .)
  trivy convert --format sarif --output "$OUT/trivy.sarif" "$OUT/trivy.json"
  trivy convert --format table "$OUT/trivy.json"
  # Harness reads the SARIF file from another container.
  chmod 755 "$OUT"; chmod 644 "$OUT/trivy.json" "$OUT/trivy.sarif"
  ;;

gate)
  [ -s "$OUT/trivy.json" ] || fail "no scan report at $OUT/trivy.json"
  LEVELS=${SCAN_SEVERITY:-HIGH,CRITICAL}
  case "${SCAN_IGNORE_FAILURE:-false}" in
    true)  echo "ignoreFailure is true: findings are reported and do not block"; exit 0 ;;
    false) ;;
    *)     fail "SCAN_IGNORE_FAILURE must be true or false" ;;
  esac
  if trivy convert --severity "$LEVELS" --exit-code 1 --format table "$OUT/trivy.json"; then
    echo "Gate passed: no findings at $LEVELS"
  else
    fail "gate failed: findings at $LEVELS (or the report could not be read). Fix them, or accept them in the ignore file with a reason."
  fi
  ;;

*) fail "unknown mode '$MODE'" ;;
esac
