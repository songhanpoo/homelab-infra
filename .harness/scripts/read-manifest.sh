#!/bin/sh
# Reads manifest.yaml for one TARGET and writes the scan settings for later pipeline steps.
#   read-manifest.sh <outputs-file>        run from the repository root; needs yq (v4)
# Env: TARGET.
# Fails on anything missing or unexpected, so a typo never silently turns the scan off.
# The values end up in pipeline conditions and an image name, so each one is checked.
set -eu

OUTPUTS="${1:?usage: read-manifest.sh <outputs-file>}"
: "${TARGET:?}"
export TARGET
FILE=manifest.yaml
fail() { echo "ERROR: $FILE: $*" >&2; exit 1; }
if command -v apk >/dev/null 2>&1; then apk add --no-cache yq >/dev/null; fi

[ -f "$FILE" ] || fail "not found"
yq -e '.' "$FILE" >/dev/null 2>&1 || fail "is not valid YAML"
get() { yq -r "$1" "$FILE"; }
req() {
  value=$(get "$1")
  [ -n "$value" ] && [ "$value" != null ] || fail "missing $1"
  printf '%s' "$value"
}
# The whole value must match. grep alone passes if any one line does, and a second line could
# add its own settings to the outputs file, so values with line breaks are refused first.
NL='
'
matches() {
  case "$1" in *"$NL"*) return 1 ;; esac
  printf '%s' "$1" | grep -Eqx -- "$2"
}
# A real YAML boolean, not a string such as "no" or "False ".
bool() {
  [ "$(get "$1 | tag")" = '!!bool' ] || fail "$1 must be true or false"
  get "$1"
}

[ "$(req .apiVersion)" = cots/v2 ] || fail "expected apiVersion cots/v2"
[ "$(get '.pipeline.targets | has(strenv(TARGET))')" = true ] || fail "pipeline.targets has no entry '$TARGET'"

IAC=.pipeline.platformScans.iac
[ "$(req $IAC.tool)" = trivy ] || fail "$IAC.tool must be trivy"
ENABLED=$(bool $IAC.enabled)
IGNORE_FAILURE=$(bool $IAC.ignoreFailure)

# Per-target overrides. Unknown keys are refused so that a misspelling is noticed.
OVERRIDE='.pipeline.targets[strenv(TARGET)].scan'
if [ "$(get "$OVERRIDE | tag")" != '!!null' ]; then
  [ "$(get "$OVERRIDE | tag")" = '!!map' ] || fail "targets.$TARGET.scan must be a map"
  for key in $(get "$OVERRIDE | keys | .[]"); do
    case "$key" in
      enabled)       ENABLED=$(bool "$OVERRIDE.enabled") ;;
      ignoreFailure) IGNORE_FAILURE=$(bool "$OVERRIDE.ignoreFailure") ;;
      *) fail "unknown key targets.$TARGET.scan.$key" ;;
    esac
  done
fi

VERSION=$(req $IAC.version)
matches "$VERSION" '[0-9]+\.[0-9]+\.[0-9]+' || fail "$IAC.version must look like 1.2.3"
case "$VERSION" in 0.69.4|0.69.5|0.69.6) fail "Trivy $VERSION was a malicious release" ;; esac
DIGEST=$(req $IAC.digest)
matches "$DIGEST" 'sha256:[0-9a-f]{64}' || fail "$IAC.digest must be sha256:<64 hex characters>"

[ "$(get "$IAC.severity | tag")" = '!!seq' ] || fail "$IAC.severity must be a list"
SEVERITY=$(get "$IAC.severity | join(\",\")")
matches "$SEVERITY" '(UNKNOWN|LOW|MEDIUM|HIGH|CRITICAL)(,(UNKNOWN|LOW|MEDIUM|HIGH|CRITICAL))*' ||
  fail "$IAC.severity must list at least one of UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL"

IGNORE_FILE=$(req $IAC.ignoreFile)
matches "$IGNORE_FILE" '[A-Za-z0-9._][A-Za-z0-9._/-]*' || fail "$IAC.ignoreFile must be a simple repo-relative path"
case "/$IGNORE_FILE/" in */../*) fail "$IAC.ignoreFile must stay inside the repository" ;; esac

{
  echo "SCAN_ENABLED=$ENABLED"
  echo "SCAN_IMAGE_TAG=$VERSION@$DIGEST"
  echo "SCAN_SEVERITY=$SEVERITY"
  echo "SCAN_IGNORE_FILE=$IGNORE_FILE"
  echo "SCAN_IGNORE_FAILURE=$IGNORE_FAILURE"
} > "$OUTPUTS"

echo "----- manifest.yaml: $TARGET -----"
if [ "$ENABLED" = true ]; then
  echo "Trivy scan: ENABLED, version $VERSION, gate on $SEVERITY"
  if [ "$IGNORE_FAILURE" = true ]; then echo "WARNING: ignoreFailure is true, so findings do not block"; fi
else
  echo "WARNING: Trivy scan is DISABLED by manifest.yaml for this target"
fi
echo "----------------------------------"
