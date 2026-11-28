#!/bin/sh
# Runs a "terraform init" command and chooses where providers are downloaded from.
#   tf-registry.sh terraform init -input=false
#
# NEXUS=auto (default)  use Nexus if it answers over verified TLS, otherwise download directly.
#                       If init through Nexus fails, try once more directly.
# NEXUS=1               require Nexus
# NEXUS=0               download directly from registry.terraform.io
# TF_NEXUS_CA           certificate to trust for this command only (the pipeline sets it).
#                       Terraform on macOS ignores this; macOS uses the keychain.
#
# Auto matters because Nexus runs in the cluster this repository builds: a rebuild must not need it.
set -u

NEXUS=${NEXUS:-auto}
REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG="$REPO_ROOT/terraform-nexus.tfrc"
PROBE_URL=${NEXUS_PROBE_URL:-https://nexus.local.proxy/repository/terraform-proxy/.well-known/terraform.json}

note() { echo "tf-registry: $*" >&2; }

case "$NEXUS" in
  auto|0|1) ;;
  *) note "NEXUS must be auto, 0 or 1 (got '$NEXUS')"; exit 2 ;;
esac

if [ -n "${TF_CLI_CONFIG_FILE:-}" ]; then
  note "TF_CLI_CONFIG_FILE is already set, so it is used unchanged"
  exec "$@"
fi
if [ "$NEXUS" = 0 ]; then
  note "downloading from registry.terraform.io (NEXUS=0)"
  exec "$@"
fi

# Nexus cannot be used: fail when it is required, otherwise go direct.
unavailable() {
  if [ "$NEXUS" = 1 ]; then note "NEXUS=1, but $1"; exit 1; fi
  note "$1; downloading from registry.terraform.io instead"
}

WORK=""
BUNDLE=""
trap 'if [ -n "$WORK" ]; then rm -rf "$WORK"; fi' EXIT

if [ -n "${TF_NEXUS_CA:-}" ]; then
  SYSTEM_ROOTS=""
  for f in /etc/ssl/certs/ca-certificates.crt /etc/ssl/cert.pem /etc/pki/tls/certs/ca-bundle.crt; do
    if [ -s "$f" ]; then SYSTEM_ROOTS=$f; break; fi
  done
  if [ -f "$TF_NEXUS_CA" ] && [ -n "$SYSTEM_ROOTS" ]; then
    WORK=$(mktemp -d)
    BUNDLE="$WORK/ca.pem"
    { cat "$SYSTEM_ROOTS"; echo; cat "$TF_NEXUS_CA"; } > "$BUNDLE"
  else
    note "cannot build a certificate bundle from TF_NEXUS_CA"
  fi
fi

probe() {
  if [ -n "$BUNDLE" ]; then set -- --cacert "$BUNDLE"; else set --; fi
  curl -fsS --max-time 8 -o /dev/null "$@" "$PROBE_URL" 2>/dev/null
}

if ! probe; then
  unavailable "Nexus did not answer over trusted TLS"
  "$@"
  exit $?
fi

note "downloading through Nexus terraform-proxy"
RC=0
if [ -n "$BUNDLE" ]; then
  SSL_CERT_FILE="$BUNDLE" TF_CLI_CONFIG_FILE="$CONFIG" "$@" || RC=$?
else
  TF_CLI_CONFIG_FILE="$CONFIG" "$@" || RC=$?
fi
if [ "$RC" -ne 0 ] && [ "$NEXUS" = auto ]; then
  unavailable "init through Nexus failed (exit $RC)"
  RC=0
  "$@" || RC=$?
fi
exit "$RC"
